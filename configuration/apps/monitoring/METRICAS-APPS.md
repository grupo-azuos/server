# Métricas de dentro dos apps

O que a [stack de monitoramento](README.md) já coleta, e como ir além para ver o que acontece dentro de
cada app (JVM, Node, Rust...). As seções 1 a 3 são referência. As seções 4 e 5 são o plano, **ainda não
implementado** aqui.

## 1. As três camadas

O node-exporter e o cAdvisor veem o container como uma caixa fechada: quanto ele gasta, não o que faz.

| Camada | Quem gera | Exemplos | Status |
|---|---|---|---|
| Máquina | node-exporter | CPU, RAM, disco, load, rede | ✅ em todos os monitorados |
| Container | cAdvisor | CPU/RAM/rede por container, reinícios | ✅ em todos os monitorados |
| **Dentro do app** | **biblioteca no código, agente ou exporter** | heap, GC, threads, event loop, req/s, latência, erros, pool do banco | ❌ a fazer |

A terceira camada depende do app: ele precisa **expor as métricas**, normalmente em `GET /metrics` no formato
texto do Prometheus. O Prometheus lê esse endpoint do mesmo jeito que lê o node-exporter.

```text
# HELP http_request_duration_seconds Duração das requisições HTTP
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",route="/clientes",status="200",le="0.1"} 1532
...
nodejs_eventloop_lag_seconds 0.0021
```

## 2. O que medir

- **Runtime:** já vem pronto com a biblioteca. Heap, GC, threads, event loop.
- **RED por rota:** **R**ate (req/s), **E**rrors (respostas 5xx) e **D**uration (latência). Na prática é um
  histograma `http_request_duration_seconds` com as labels `method`, `route` e `status`. É o que mais ajuda no dia a dia.
- **Negócio:** contadores que você define, por exemplo `crm_leads_criados_total` ou `automacao_jobs_falhos_total`.

Cuidado com a **cardinalidade**: label com valor ilimitado (ID de usuário, URL com ID, e-mail) cria uma série
por valor e infla o Prometheus. Use a rota (`/clientes/:id`), nunca a URL real.

## 3. Por linguagem

| Runtime | Como instrumentar | O que vem de graça | Dashboard (ID no Grafana) |
|---|---|---|---|
| **JVM** (Java/Kotlin) | Spring Boot: Actuator + Micrometer (`/actuator/prometheus`). Fora do Spring: [JMX exporter](https://github.com/prometheus/jmx_exporter) como `-javaagent`, **sem mexer no código** | heap/non-heap, pausas de GC, threads, classes, pool do Hikari, latência HTTP | `4701` (JVM Micrometer) |
| **Node** | [`prom-client`](https://github.com/siimon/prom-client) + `collectDefaultMetrics()` | lag do event loop, heap do V8, GC, handles abertos | `11159` (NodeJS Application) |
| **Rust** | crate [`metrics`](https://docs.rs/metrics) + `metrics-exporter-prometheus` (no axum: `axum-prometheus`). Para o Tokio: `tokio-metrics` | só o que você instrumenta, mais métricas do processo. Não há VM, então não há heap nem GC para medir | montado por você |
| **Go** | `client_golang` | goroutines, GC, memória | `10826` (Go Metrics) |
| **Python** | `prometheus_client` (FastAPI: `prometheus-fastapi-instrumentator`) | processo e HTTP | — |
| **Bancos e serviços** | exporter ao lado: `postgres_exporter`, `redis_exporter`... | conexões, queries lentas, cache hit, replicação | `9628` (PostgreSQL) |

> O `rustc` é só o compilador. O que se mede é o binário que ele gera.

**Regra para todos:** sirva o `/metrics` numa **porta separada** da aplicação (nos exemplos, a `9464`).
Assim o Traefik nunca publica as métricas na internet.

### JVM: Spring Boot

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

```properties
management.server.port=9464
management.endpoints.web.exposure.include=health,prometheus
```

Métricas em `http://<container>:9464/actuator/prometheus`. A latência HTTP por rota já vem pronta (`http_server_requests_seconds`).

### Node

```js
import express from 'express';
import client from 'prom-client';

client.collectDefaultMetrics();

const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duração das requisições HTTP',
  labelNames: ['method', 'route', 'status'],
});

app.use((req, res, next) => {
  const end = httpDuration.startTimer();
  res.on('finish', () => end({ method: req.method, route: req.route?.path ?? 'outra', status: res.statusCode }));
  next();
});

// Porta separada, fora do Traefik
const metrics = express();
metrics.get('/metrics', async (_req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
metrics.listen(9464);
```

### Rust

```rust
use metrics_exporter_prometheus::PrometheusBuilder;

// Sobe o /metrics na 9464 em segundo plano
PrometheusBuilder::new()
    .with_http_listener(([0, 0, 0, 0], 9464))
    .install()
    .expect("exporter de métricas");

// No código
metrics::counter!("crm_leads_criados_total").increment(1);
metrics::histogram!("http_request_duration_seconds", "route" => "/clientes").record(elapsed.as_secs_f64());
```

## 4. Como o Prometheus chega no app

O problema é **descobrir os apps**: os do Coolify nascem e morrem, e editar o `prometheus.yml` a cada
deploy não escala. Há dois caminhos.

### A. Porta no IP do NetBird + lista fixa (para começar)

Igual aos exporters: o container publica a porta de métricas **só no IP do NetBird**. No Coolify, em Ports
Mappings: `<IP NetBird do servidor>:9464:9464`. Depois, o app entra no `prometheus.yml`.

- **A fazer:** o [`prometheus.yml.j2`](config/prometheus.yml.j2) ainda não tem uma lista de apps. Ao instrumentar o primeiro, acrescentamos um job `apps` alimentado por uma variável (por exemplo `app_metrics`, com servidor, porta e nome).
- **Bom para:** poucos apps fixos e para validar o fluxo de ponta a ponta.
- **Ruim para:** muitos apps, porque cada um consome uma porta e exige editar a lista.

### B. Agente por servidor com descoberta automática (para escalar)

```text
cada servidor
  app (container) ──/metrics──▶ Grafana Alloy (agente local)
                                  · descobre os containers pelo Docker
                                  · só lê os que tiverem label (ex.: metrics.port=9464)
                                  · pode ler logs e traces também
                                        │ remote write pela VPN
                                        ▼
monitoramento
  Prometheus (+ Loki/Tempo, se quiser) ──▶ Grafana
```

- Para monitorar um app novo, basta uma label no container (pelo Coolify ou pelo compose), sem mexer no Prometheus.
- O `/metrics` não sai do servidor: só o agente local lê.
- O Alloy pode substituir o node-exporter e o cAdvisor, e vira um agente só por servidor.
- **No Prometheus:** ligar `--web.enable-remote-write-receiver` para aceitar os dados enviados.

## 5. OpenTelemetry: métricas + traces + logs

Em vez de uma biblioteca do Prometheus para cada linguagem, há o SDK do **OpenTelemetry**: um padrão só para
métricas, **traces** (o caminho de uma requisição entre serviços e banco) e logs.

| Runtime | Instrumentação |
|---|---|
| Java | agente `opentelemetry-javaagent.jar`, **sem mexer no código** (HTTP, JDBC, filas) |
| Node | `@opentelemetry/auto-instrumentations-node` (HTTP, Express, pg, Redis...) |
| Rust | manual: `tracing` + `tracing-opentelemetry` + `opentelemetry-otlp` |

O app envia (OTLP) para o agente do caminho B. As métricas vão para o Prometheus, os traces para o
**Tempo** e os logs para o **Loki**, e os três aparecem no mesmo Grafana.

Vale a pena quando houver vários serviços conversando entre si e a pergunta for "onde esta requisição ficou lenta?".

## 6. Ordem sugerida

1. **Um app só** (por exemplo o CRM): ligar a biblioteca da linguagem, com runtime + histograma HTTP, na porta `9464`.
2. **Caminho A:** porta no IP do NetBird, job `apps` no `prometheus.yml.j2` e o dashboard da linguagem importado.
3. **Quando houver vários apps:** caminho B, com Alloy e descoberta por label.
4. **Se precisar de traces:** OpenTelemetry + Tempo, e logs com Loki.

As métricas por container também ajudam a decidir sobre o Coolify: elas mostram quanto o próprio Coolify
(Traefik, banco, workers) consome em cada servidor.

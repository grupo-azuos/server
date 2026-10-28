# Monitoramento: Prometheus + Grafana

Trazido do my-config (`configuration/apps/monitoring`) e dividido em duas partes: os agentes rodam em
cada servidor e o Prometheus do `ops` coleta todos pelo NetBird.

```text
homo, auto, crm, core, ops
  node-exporter  <IP NetBird>:9100   (host: CPU, RAM, disco, rede, load)
  cAdvisor       <IP NetBird>:9101   (uso de cada container Docker)
        ▲
        │ VPN NetBird (scrape a cada 15s)
        │
ops
  Prometheus     <IP NetBird>:9090   (15 dias ou 5 GB de histórico)
  Grafana        <IP NetBird>:3000   (Prometheus já cadastrado como fonte de dados)
```

Tudo usa a rede do host e escuta **só no IP do NetBird** (`wt0`): nada fica exposto no IP público, sem
regra de firewall nem proxy. Para abrir o Grafana, conecte-se à VPN e acesse `http://<IP do ops no NetBird>:3000`.

## Arquivos

| Arquivo | Vai para | Onde roda |
|---|---|---|
| `compose.exporters.yml` | `/opt/exporters` | todo servidor do grupo `monitorados` |
| `compose.yml` | `/opt/monitoring` | `ops` |
| `config/prometheus.yml.j2` | `/opt/monitoring/config/prometheus.yml` | gerado com os IPs do NetBird de cada monitorado |
| `config/grafana/provisioning/` | `/opt/monitoring/config/grafana/` | fonte de dados e pasta de dashboards |
| `dashboards/` | `/opt/monitoring/dashboards/` | JSONs exportados do Grafana (opcional) |

Quem é monitorado é o grupo `monitorados`, em [`servers/groups.yml`](../../servers/groups.yml). Para
incluir o prod, acrescente `'prod'` na lista e rode as duas etapas de novo.

## Deploy

Pré-requisito: o servidor já está no NetBird (etapa `netbird-client`), e os servidores sem Coolify já têm Docker (etapa `docker`).

```bash
# 1. Agentes em todos os monitorados
ansible-playbook configuration/ansible/deploy.yml --tags exporters

# 2. Prometheus + Grafana (lê o IP do NetBird de cada monitorado por SSH)
ansible-playbook configuration/ansible/deploy.yml --tags monitoring --limit ops
```

O IP de cada servidor vem da interface `wt0`. Se precisar fixar, use `vpn_ip=` na linha do `hosts.ini`.
Ao fim, a etapa `monitoring` lista os alvos que ainda não estão `up`.

Conferir:
- `http://<IP do ops>:9090/targets`: todos os alvos `UP`.
- `http://<IP do ops>:3000`: login com `admin` e o `grafana_admin_password` do `hosts.ini`.

A senha do Grafana só vale na primeira subida; depois disso, troque pelo próprio Grafana.

## Dashboards

Em **Dashboards → New → Import**, importe os IDs da comunidade:

- **`1860`**: *Node Exporter Full* (host). Escolha o servidor no seletor `instance`.
- **`14282`**: *cAdvisor exporter* (containers).

Os alvos usam `instance=<nome do servidor>` (`homo`, `crm`...) em vez de `IP:porta`, então os seletores
mostram o nome. Para versionar um dashboard, exporte o JSON e salve em `dashboards/`.

## Métricas de dentro dos apps

Esta stack vê máquina e container. Para JVM, Node, Rust e afins (heap, GC, event loop, latência por rota),
o app precisa expor `/metrics`. O plano está em [METRICAS-APPS.md](METRICAS-APPS.md).

## Remover

```bash
ansible-playbook configuration/ansible/clean.yml --tags monitoring --limit ops   # + -e remove_volumes=true apaga o histórico
ansible-playbook configuration/ansible/clean.yml --tags exporters
```

## Cuidados

- **Política do NetBird.** O ops precisa alcançar as portas 9100 e 9101 dos outros peers. A
  política padrão (`All`) já libera; se ela for restringida, crie uma regra ops → monitorados nessas portas.
- **IP do NetBird mudou** (peer removido e recriado): rode as duas etapas de novo.
- **Versões.** As mesmas do my-config (Prometheus 2.51, Grafana 10.4, node-exporter 1.7, cAdvisor 0.49).

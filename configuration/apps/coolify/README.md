# Coolify e Traefik

Os dois servidores rodam Coolify, e o proxy de cada um é o Traefik do próprio Coolify (`coolify-proxy`).

```text
*.grupoazuos.com.br       ─▶ prod (Traefik do prod) ─▶ app do prod
*.homo.grupoazuos.com.br  ─▶ prod (passthrough por SNI, homo.yaml) ─▶ túnel NetBird ─▶ Traefik do homo ─▶ app do homo
```

| Servidor | Painel | Wildcard domain | Rede dos apps |
|---|---|---|---|
| prod (Hostinger) | `https://coolify.grupoazuos.com.br` | `https://grupoazuos.com.br` | `prod` |
| homo | `https://coolify.homo.grupoazuos.com.br` (ou `http://100.85.230.136:8000` pela VPN) | `https://homo.grupoazuos.com.br` | `coolify` |

O homo **não** é acessado por SSH nem por Ansible. Todo ajuste nele é feito pelo painel do Coolify.

## Ajustes no proxy

O Coolify guarda o `docker-compose.yml` do proxy no próprio banco. Edite em **Servers → \<servidor\> → Proxy**,
clique em **Save** e depois em **Restart Proxy**. O restart derruba por alguns segundos todos os sites daquele servidor.

**prod**, logo abaixo de `--entrypoints.https.address=:443`:

```yaml
- '--entrypoints.https.transport.respondingTimeouts.readTimeout=0'   # streams gRPC do NetBird
```

**homo**:

```yaml
- '--entrypoints.https.address=:443'
- '--entrypoints.https.proxyProtocol.trustedIPs=100.64.0.0/10'       # IP real vindo do túnel (só da faixa da VPN)
- '--certificatesresolvers.letsencrypt.acme.tlschallenge=true'       # no lugar do httpchallenge (+ remover o httpchallenge.entrypoint)
```

Se alguém usar **Reset Configuration** no proxy, esses ajustes se perdem e precisam ser refeitos.
No prod, a rota `*.homo` fica em **Dynamic Configurations → homo.yaml** e é gerada pelo Ansible
(`ansible/deploy.tunnel-prod.yml`, a partir de `config/homo.yaml.j2`).

## Labels: cada app com as suas

Cada app define **todos** os middlewares que usa nas próprias Container Labels, sempre com o nome do app na frente.
Não use `xxx@docker` de outro container nem middleware "global". Se um container define um middleware que outros usam,
basta um redeploy dele, ou uma configuração errada, para quebrar todos os outros.

Regras:

- `traefik.docker.network` deve ser a rede onde o container realmente está: `prod` no prod e `coolify` no homo.
- `loadbalancer.server.port` deve ser a porta em que o app escuta, que pode ser diferente do "Ports Exposes".
- Sempre há um router `http` com o redirect do próprio app, além do router `https`.
- O `forwardauth` chama o admin-console do mesmo servidor: `http://admin-console:3000` no prod e
  `http://admin-console:4000` no homo.

Modelo (troque `APP`, `HOST`, `PORTA` e `REDE`):

```properties
traefik.enable=true
traefik.docker.network=REDE

traefik.http.middlewares.APP-redirect.redirectscheme.scheme=https
traefik.http.middlewares.APP-redirect.redirectscheme.permanent=true
traefik.http.middlewares.APP-gzip.compress=true
traefik.http.middlewares.APP-headers.headers.contentTypeNosniff=true
traefik.http.middlewares.APP-headers.headers.frameDeny=true
traefik.http.middlewares.APP-headers.headers.stsIncludeSubdomains=true
traefik.http.middlewares.APP-headers.headers.stsSeconds=31536000
traefik.http.middlewares.APP-rate.ratelimit.average=200
traefik.http.middlewares.APP-rate.ratelimit.burst=100
# Só para apps protegidos pelo login do admin-console:
traefik.http.middlewares.APP-auth.forwardauth.address=http://admin-console:3000/api/auth/verify
traefik.http.middlewares.APP-auth.forwardauth.authResponseHeaders=x-forwarded-user-id,x-forwarded-user-email,x-forwarded-user-name,x-forwarded-user-role
traefik.http.middlewares.APP-auth.forwardauth.addAuthCookiesToResponse=azuos_homo_access_token,azuos_homo_refresh_token
traefik.http.middlewares.APP-strip-cookie.headers.customrequestheaders.Cookie=

traefik.http.routers.APP-http.entrypoints=http
traefik.http.routers.APP-http.rule=Host(`HOST`)
traefik.http.routers.APP-http.middlewares=APP-redirect
traefik.http.routers.APP-http.service=APP

traefik.http.routers.APP.entrypoints=https
traefik.http.routers.APP.rule=Host(`HOST`)
traefik.http.routers.APP.tls=true
traefik.http.routers.APP.tls.certresolver=letsencrypt
traefik.http.routers.APP.middlewares=APP-headers,APP-rate,APP-gzip
traefik.http.routers.APP.service=APP

traefik.http.services.APP.loadbalancer.server.port=PORTA
```

Depois de mudar as labels: **Save** e **Restart** do app. O restart recria o container com as labels novas, sem rebuild.

## Apps com labels manuais

| Servidor | App | Host | Porta | Middlewares |
|---|---|---|---|---|
| prod | admin-console | `admin-console.grupoazuos.com.br` | 3000 | headers, rate, gzip |
| prod | brand | `brand.grupoazuos.com.br` | 3000 | headers, rate, auth, strip-cookie (preview e public sem auth) |
| prod | paralegal | `paralegal.grupoazuos.com.br` | 3002 | headers, rate, auth, strip-cookie |
| prod | public-api | `public.grupoazuos.com.br` | 3001 | headers, rate, gzip |
| homo | admin-console | `admin-console.homo.grupoazuos.com.br` | 4000 | headers, rate, gzip |
| homo | paralegal | `paralegal.homo.grupoazuos.com.br` | 4002 | headers, rate, auth, strip-cookie |
| homo | public-api | `public-api.homo.grupoazuos.com.br` | 4001 | headers, rate, gzip |

Os demais apps do prod (fiscal, trilha, crm, certmonitor, cs, onecode-automation, azuosclip) usam as labels geradas
pelo Coolify. Elas também são autocontidas.

## Diagnóstico rápido

| Sintoma | Causa provável |
|---|---|
| `Bad Gateway` | A porta em `loadbalancer.server.port` não é a porta em que o app escuta |
| `no available server` | O container está fora da rede de `traefik.docker.network`, ou está unhealthy ou em loop de crash (ver Logs do app) |
| `middleware "x@docker" does not exist` (logs do proxy) | O app usa um middleware de outro container. Defina-o nas labels do próprio app |
| `Middleware defined multiple times with different configurations` | Vários containers definem o mesmo nome de middleware. Use nomes com o prefixo do app |
| Erro de certificado em `*.homo` | O proxy do homo está sem `tlschallenge`/`proxyProtocol`. Refaça os ajustes de proxy acima |

Os logs ficam em **Servers → \<servidor\> → Proxy → Logs** (proxy) e na aba **Logs** de cada app.

## Histórico

### 2026-10-13/14: correção do roteamento prod/homo

Situação encontrada:

- **admin-console (prod)** dava `Bad Gateway`: a label apontava a porta 4000, mas o app escuta na 3000.
  A rede também estava errada (`coolify` em vez de `prod`).
- **brand** e **paralegal (prod)** dependiam de `um-auth`, `um-headers` e `strip-session-cookie`, que só existiam
  no admin-console. O `um-auth` chamava a porta errada.
- **public-api (prod)** usava `gzip@docker` de outro app. Todos usavam `redirect-to-https@docker`, que estava
  quebrado por definições conflitantes.
- **Proxy do prod** estava sem `readTimeout=0`.
- **Proxy do homo** estava com a configuração padrão do Coolify: desafio HTTP e sem PROXY protocol.
  O wildcard domain do homo estava vazio.
- **admin-console (homo)** estava em loop de crash (`LOGIN_URL` era `http://192.168.10.60:4000` e o app exige https).
  O paralegal e o public-api do homo dependiam de middlewares de outro container.

O que foi feito, tudo pelo painel do Coolify:

1. Labels autocontidas, no modelo acima, nos 4 apps de labels manuais do prod e nos 3 do homo, com rede e porta corretas.
2. Proxy do prod: `readTimeout=0` e restart.
3. Proxy do homo: `tlschallenge`, `proxyProtocol.trustedIPs=100.64.0.0/10` e restart.
4. Wildcard domain do homo: `https://homo.grupoazuos.com.br`.
5. `LOGIN_URL` do admin-console do homo: `https://admin-console.homo.grupoazuos.com.br`.

Pendências:

- `API_CORS_ORIGIN` do admin-console do homo ainda aponta para o admin-console do prod e para IPs da LAN. O correto é
  `https://admin-console.homo.grupoazuos.com.br`.
- O `token-radar-app` (prod) fica fora do Coolify e ainda usa `redirect-to-https`/`gzip` de outros apps. Ele precisa
  de labels próprias no compose dele.
- O prod usa `COOKIE_NAME_PREFIX=azuos_homo`. Funciona, mas trocar o prefixo desloga todos os usuários.

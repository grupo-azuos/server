# NetBird

VPN mesh (WireGuard) self-hosted. No prod roda o **server** (Management, Signal, Relay/STUN e IdP embarcado)
e o **dashboard**, publicados em `https://netbird.<domain>` pelo Traefik do Coolify. Os dois servidores rodam
o **client** no host.

| Arquivo | Uso |
|---|---|
| `compose.yml` | Deploy direto no Docker pelo Ansible (`--tags netbird`), em `/opt/netbird` |
| `compose.coolify.yml` | Mesmo serviço para colar no Coolify (config inline, sem `container_name`) |
| `config/config.yaml.j2`, `config/dashboard.env.j2` | Configs geradas pelo Ansible |
| `ansible/deploy.server.yml`, `deploy.client.yml` | Tasks de deploy (tags `netbird`, `netbird-client`) |
| `ansible/clean.server.yml`, `clean.client.yml` | Teardown |

Roteamento no Traefik (equivalente ao `netbird.caddy` do my-config):

| Caminho | Destino |
|---|---|
| `/signalexchange.SignalExchange/*`, `/management.ManagementService/*` (gRPC) | `netbird-server:80` em h2c |
| `/api`, `/oauth2`, `/relay`, `/ws-proxy` | `netbird-server:80` |
| resto | `netbird-dashboard:80` |

## Pré-requisito: readTimeout no Traefik do Coolify

O Traefik v3 corta conexões com mais de 60s de leitura, e os streams gRPC do NetBird ficam abertos o tempo
todo. O deploy pelo Ansible já faz este ajuste; pelo Coolify, é manual:

1. **Servers → localhost → Proxy**.
2. No `command:`, logo abaixo de `- '--entrypoints.https.address=:443'`, acrescente:
   ```yaml
   - '--entrypoints.https.transport.respondingTimeouts.readTimeout=0'
   ```
3. **Save** e **Restart Proxy**.

Conferir no prod: `docker inspect coolify-proxy | grep readTimeout`.

## Deploy pelo Coolify

1. Gere três segredos: `openssl rand -base64 32` (rode três vezes).
2. Copie `compose.coolify.yml`, troque os três `GERAR_COM_OPENSSL` pelos segredos e, se o domínio for outro,
   `netbird.grupoazuos.com.br`.
3. No Coolify: **Projects → + New → Docker Compose Empty**, cole o compose e salve.
4. Deixe vazios os campos **Domains** dos dois serviços (o roteamento vem das labels).
5. Em **Settings** do recurso, marque **Connect To Predefined Network**.
6. **Deploy**.

Guarde o compose preenchido em lugar seguro: os segredos não podem mudar depois, senão o banco do NetBird não
abre e as sessões caem.

## Deploy direto no Docker

```bash
ansible-playbook configuration/ansible/deploy.yml --tags netbird --limit prod
```

Os segredos são gerados na primeira vez em `/opt/netbird/config.yaml` e nunca sobrescritos. O banco fica em
`/opt/netbird/data`.

## Conferir

```bash
curl -sI https://netbird.<domain>              # 200, painel
curl -s  https://netbird.<domain>/api/users    # 401: API respondendo
docker logs netbird-server --tail 20           # pelo Coolify, o nome tem o sufixo do recurso
```

No primeiro acesso ao painel, crie o usuário admin. Depois, em **Setup Keys**, gere a chave usada por
`netbird_setup_key` nos `hosts.ini`.

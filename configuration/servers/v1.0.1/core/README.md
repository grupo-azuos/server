# Servidor core

Sistemas internos da empresa.

## O que roda aqui

| Serviço | Onde | Endereço | Etapa |
|---|---|---|---|
| Docker | systemd | | `docker` |
| NetBird Client | systemd (`netbird.service`) | `wt0` | `netbird-client` |
| node-exporter + cAdvisor | Docker (`/opt/exporters`) | `<IP NetBird>:9100`, `:9101` | `exporters`, ver [apps/monitoring](../../../apps/monitoring/README.md) |
| Komodo Periphery | Docker (`/opt/komodo-periphery`) | conecta no Core pela VPN | `komodo-periphery`, ver [apps/komodo](../../../apps/komodo/README.md) |
| Caddy | Docker (`/opt/caddy`) | borda, TLS automático, `:80`/`:443` | `caddy`, ver [apps/caddy](../../../apps/caddy/README.md) |

Ainda sem Coolify: por enquanto só entra na VPN e é monitorado.

## Rotas do Caddy

Em [`vars.yml`](vars.yml) (`caddy_routes`), versionado. Formato em [apps/caddy](../../../apps/caddy/README.md#rotas).

## Inventário

Copie [`hosts.ini.example`](hosts.ini.example) para `hosts.ini` (ignorado pelo git) e preencha. É o mesmo conteúdo das secrets do GitHub Actions.

| Variável | Para quê |
|---|---|
| `domain` | Domínio base (mesmo do prod) |
| `email` | Contato |
| `netbird_setup_key` | Conecta o agente NetBird na VPN |
| `vpn_ip` | *(Opcional)* IP no NetBird; sem ele, é lido da `wt0` |
| `komodo_onboarding_key` | Registra o agente no Komodo (criada no painel) |

## Deploy

```bash
ansible-playbook configuration/ansible/deploy.yml --tags docker --limit core
ansible-playbook configuration/ansible/deploy.yml --tags netbird-client --limit core
ansible-playbook configuration/ansible/deploy.yml --tags exporters --limit core
ansible-playbook configuration/ansible/deploy.yml --tags komodo-periphery --limit core
ansible-playbook configuration/ansible/deploy.yml --tags caddy --limit core
```

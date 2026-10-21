# Servidor crm

Só o CRM.

## O que roda aqui

| Serviço | Onde | Endereço | Etapa |
|---|---|---|---|
| Docker | systemd | | `docker` |
| NetBird Client | systemd (`netbird.service`) | `wt0` | `netbird-client` |
| node-exporter + cAdvisor | Docker (`/opt/exporters`) | `<IP NetBird>:9100`, `:9101` | `exporters`, ver [apps/monitoring](../../apps/monitoring/README.md) |

Ainda sem Coolify: por enquanto só entra na VPN e é monitorado.

## Inventário

Copie [`inventory.ini`](inventory.ini) para `hosts.ini` (ignorado pelo git) e preencha.

| Variável | Para quê |
|---|---|
| `domain` | Domínio base (mesmo do prod) |
| `email` | Contato |
| `netbird_setup_key` | Conecta o agente NetBird na VPN |
| `vpn_ip` | *(Opcional)* IP no NetBird; sem ele, é lido da `wt0` |

## Deploy

```bash
ansible-playbook configuration/ansible/deploy.yml --tags docker --limit crm
ansible-playbook configuration/ansible/deploy.yml --tags netbird-client --limit crm
ansible-playbook configuration/ansible/deploy.yml --tags exporters --limit crm
```

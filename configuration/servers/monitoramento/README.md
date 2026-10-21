# Servidor monitoramento

Monitora todos os servidores: Prometheus coleta os exporters de cada um pelo NetBird e o Grafana mostra os painéis. Acesso só pela VPN.

## O que roda aqui

| Serviço | Onde | Endereço | Etapa |
|---|---|---|---|
| Docker | systemd | | `docker` |
| NetBird Client | systemd (`netbird.service`) | `wt0` | `netbird-client` |
| node-exporter + cAdvisor | Docker (`/opt/exporters`) | `<IP NetBird>:9100`, `:9101` | `exporters`, ver [apps/monitoring](../../apps/monitoring/README.md) |
| Prometheus | Docker (`/opt/monitoring`) | `http://<IP NetBird>:9090` | `monitoring` |
| Grafana | Docker (`/opt/monitoring`) | `http://<IP NetBird>:3000` | `monitoring` |

Sem Coolify.

## Inventário

Copie [`inventory.ini`](inventory.ini) para `hosts.ini` (ignorado pelo git) e preencha.

| Variável | Para quê |
|---|---|
| `domain` | Domínio base (mesmo do prod) |
| `email` | Contato |
| `netbird_setup_key` | Conecta o agente NetBird na VPN |
| `vpn_ip` | *(Opcional)* IP no NetBird; sem ele, é lido da `wt0` |
| `grafana_admin_password` | Senha do `admin` do Grafana na primeira subida |

## Deploy

```bash
ansible-playbook configuration/ansible/deploy.yml --tags docker --limit monitoramento
ansible-playbook configuration/ansible/deploy.yml --tags netbird-client --limit monitoramento
ansible-playbook configuration/ansible/deploy.yml --tags exporters --limit monitoramento
ansible-playbook configuration/ansible/deploy.yml --tags monitoring --limit monitoramento   # depois dos exporters nos outros
```

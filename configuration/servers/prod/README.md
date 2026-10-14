# Servidor prod

VPS pública e borda da rede: hospeda o NetBird e repassa `*.homo.<domain>` pelo túnel, sem abrir o TLS,
para o [homo](../homo/README.md).

## O que roda aqui

| Serviço | Onde | Endereço | Etapa |
|---|---|---|---|
| Coolify | Docker (`/data/coolify`) | `http://<ip>:8000` | `coolify` |
| Traefik (coolify-proxy) | Docker | `:80`, `:443` | `coolify` |
| NetBird Server + Dashboard | Docker (`/opt/netbird`) | `netbird.<domain>`, `3478/udp` | `netbird` |
| NetBird Client | systemd (`netbird.service`) | `wt0` | `netbird-client` |
| Túnel para o homo | Traefik (`/data/coolify/proxy/dynamic/homo.yaml`) | `*.homo.<domain>` | `tunnel` |
| RustDesk (hbbs + hbbr) | Coolify, projeto `rede` (rede do host) | `21115-21117/tcp`, `21116/udp` | manual, ver [apps/rustdesk](../../apps/rustdesk/README.md) |

## Inventário

Copie [`inventory.ini`](inventory.ini) para `hosts.ini` (ignorado pelo git) e preencha.

| Variável | Para quê |
|---|---|
| `domain` | Domínio base: `netbird.<domain>` e `*.homo.<domain>` |
| `email` | Conta ACME (Let's Encrypt) |
| `netbird_auth_secret`, `netbird_session_key`, `netbird_datastore_key` | *(Opcional)* Segredos do NetBird server (`openssl rand -base64 32`). Sem eles, o Ansible gera na primeira instalação e guarda em `/opt/netbird/config.yaml` |
| `netbird_setup_key` | Conecta o agente NetBird na VPN (gerada após a etapa `netbird`) |
| `coolify_root_email`, `coolify_root_password` | Admin do Coolify na instalação |

## Deploy

```bash
ansible-playbook configuration/ansible/deploy.yml --tags <etapa> --limit prod
```

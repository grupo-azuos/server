# Servidor homo

Homologação. O Coolify daqui atende `*.homo.<domain>` e tem os certificados dos apps; o
[prod](../prod/README.md) só repassa a conexão TLS pelo túnel do NetBird.

## O que roda aqui

| Serviço | Onde | Endereço | Etapa |
|---|---|---|---|
| Coolify | Docker (`/data/coolify`) | `http://<ip>:8000` | `coolify` |
| Traefik (coolify-proxy) | Docker | `:443` (recebe do prod pela VPN) | `coolify` |
| NetBird Client | systemd (`netbird.service`) | `wt0` | `netbird-client` |
| Supabase (self-hosted) | Docker (`/opt/supabase`) | `http://<ip>:8001` (API, Studio e S3), `:5432` | `supabase`, ver [apps/supabase](../../apps/supabase/README.md) |

Apps no Coolify daqui usam domínio com **`https://`** (`https://app.homo.<domain>`), como sempre. O proxy
daqui usa desafio ACME TLS-ALPN (o único que passa pelo passthrough do prod) e aceita PROXY protocol da VPN,
para os apps verem o IP real do cliente. Ajustes e labels: [apps/coolify](../../apps/coolify/README.md).

**Sem SSH:** este servidor é alterado só pelo painel do Coolify (`https://coolify.homo.<domain>`, ou
`http://<IP do NetBird>:8000`).

## Inventário

Copie [`inventory.ini`](inventory.ini) para `hosts.ini` (ignorado pelo git) e preencha.

| Variável | Para quê |
|---|---|
| `domain` | Domínio base (mesmo do prod) |
| `email` | Contato |
| `netbird_setup_key` | Conecta o agente NetBird na VPN |
| `coolify_root_email`, `coolify_root_password` | Admin do Coolify na instalação |

## Deploy

A instalação inicial (etapas `coolify` e `netbird-client`) usa
`ansible-playbook configuration/ansible/deploy.yml --tags <etapa> --limit homo`. Depois disso, as mudanças são
feitas pelo painel do Coolify. Exceção: o Supabase (`/opt/supabase`), atualizado por
`ansible-playbook configuration/ansible/deploy.yml --tags supabase --limit homo` (ver [apps/supabase](../../apps/supabase/README.md)).

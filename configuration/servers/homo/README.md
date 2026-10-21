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
| S3 público do Supabase | Dynamic Configuration `supabase-s3.yaml` do proxy | `https://s3.homo.<domain>/storage/v1/s3` | painel, ver [apps/supabase](../../apps/supabase/README.md#endpoint-s3-público-links-assinados) |
| node-exporter + cAdvisor | Docker (`/opt/exporters`) | `<IP NetBird>:9100`, `:9101` | `exporters`, ver [apps/monitoring](../../apps/monitoring/README.md) |

Apps no Coolify daqui usam domínio com **`https://`** (`https://app.homo.<domain>`), como sempre. O proxy
daqui usa desafio ACME TLS-ALPN (o único que passa pelo passthrough do prod) e aceita PROXY protocol da VPN,
para os apps verem o IP real do cliente. Ajustes e labels: [apps/coolify](../../apps/coolify/README.md).

> **Levando um app para o homo?** Domínio e labels **não** são os do prod: `*.homo.grupoazuos.com.br`, rede
> `coolify`, porta e `forwardauth` do homo, e URLs/cookies do ambiente apontando para o homo. Checklist em
> [apps/coolify → Traefik do homo](../../apps/coolify/README.md#traefik-do-homo-o-que-muda-num-app).

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
feitas pelo painel do Coolify. Exceções: os exporters (`--tags exporters --limit homo`) e o Supabase (`/opt/supabase`), atualizado por
`ansible-playbook configuration/ansible/deploy.yml --tags supabase --limit homo` (ver [apps/supabase](../../apps/supabase/README.md)).

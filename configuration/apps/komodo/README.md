# Komodo: painel de deploy dos servidores

[Komodo](https://komo.do) v2: um painel (Core) gerencia o Docker de todos os servidores por um agente
(Periphery) em cada um. Os stacks vêm do git e cada um escolhe o servidor onde roda.

```text
ops (grupo komodo_core)
  Komodo Core + Mongo   http://<IP NetBird>:9120   (painel, só pela VPN)
        ▲
        │ WebSocket pela VPN, autenticado por par de chaves (o agente é quem conecta)
        │
homo, auto, crm, core, ops (grupo komodo)
  Komodo Periphery      sem porta publicada; age no Docker local (/var/run/docker.sock)
                        stacks e repos em /etc/komodo
```

Quem roda o quê fica em [`servers/groups.yml`](../../servers/groups.yml): `komodo_core` (um servidor só) e `komodo`.

## Domínio e certificado: quem cuida é o Caddy

Funciona como o Portainer, não como o Coolify: **não tem proxy embutido nem campo de domínio**. O Komodo só
roda o `docker compose` do projeto; o domínio e o certificado são do Caddy de cada servidor:

```text
crm/  (repo do projeto)
  compose.yml          # comum
  compose.homo.yml     # o que muda na homologação (variáveis, rede caddy)
  compose.prod.yml     # o que muda na produção
```

No Komodo viram dois stacks com o mesmo repo: `crm-homo` (arquivos `compose.yml` + `compose.homo.yml`,
servidor `homo`) e `crm-prod` (`compose.yml` + `compose.prod.yml`, servidor `crm`). O proxy é o
[Caddy](../caddy/README.md): o app entra na rede `caddy` e ganha uma rota no `vars.yml` do servidor.

## Arquivos

| Arquivo | Vai para | Onde roda |
|---|---|---|
| `compose.core.yml` | `/opt/komodo` | `komodo_core` |
| `config/secrets.env.j2` | `/opt/komodo/secrets.env` | gerado uma vez, nunca sobrescrito |
| `compose.periphery.yml` | `/opt/komodo-periphery` | todo servidor do grupo `komodo` |
| `config/periphery.env.j2` | `/opt/komodo-periphery/periphery.env` | endereço do Core, nome e onboarding key |

Baseados nos composes oficiais da v2 (`compose/mongo.compose.yaml` e `compose/periphery.compose.yaml`).
As versões ficam no `vars:` do `deploy.yml` (`komodo_version`, `komodo_mongo_version`).

## Deploy

Pré-requisitos: o servidor já está no NetBird (`netbird-client`) e já tem Docker (`docker`).

**1. Painel**: com `komodo_admin_password` no `hosts.ini` do `ops`:

```bash
ansible-playbook configuration/ansible/deploy.yml --tags komodo --limit komodo_core
```

Conferir: `http://<IP NetBird do ops>:9120`, login `admin` com a senha do `hosts.ini`.

**2. Onboarding key (manual)**: no painel, em **Settings → Onboarding**, crie uma chave (reutilizável: serve para todos) e coloque em
`komodo_onboarding_key` no `hosts.ini` de cada servidor. Mesma ideia da Setup Key do NetBird.

**3. Agentes**:

```bash
ansible-playbook configuration/ansible/deploy.yml --tags komodo-periphery
```

Cada agente entra no painel com o nome do `server=` (`homo`, `crm`...). Conferir: todos em **Servers**, `OK`.
Depois do primeiro registro, a onboarding key não é mais necessária para aquele servidor.

## Remover

```bash
ansible-playbook configuration/ansible/clean.yml --tags komodo-periphery   # + -e remove_volumes=true apaga as chaves
ansible-playbook configuration/ansible/clean.yml --tags komodo --limit komodo_core
```

O `/etc/komodo` dos servidores fica: lá estão os stacks publicados e os backups do banco.

## Cuidados

- **O agente controla o Docker inteiro do servidor** (equivale a root). Ele não publica porta e o painel
  só escuta no IP do NetBird. Mantenha assim, e dê acesso ao painel só a quem pode mexer nos servidores.
- **Webhook do GitHub** (deploy no push): o Caddy do ops publica só `/listener/*` em
  `https://komodo.<domain>` (rota em `servers/v1.0.1/ops/vars.yml`); o painel continua só na VPN. Precisa do
  registro A `komodo` na Cloudflare, só DNS, com o IP do ops.
- **Chaves.** O Core guarda o par de chaves no volume `komodo-keys`; cada agente grava a chave pública do Core
  na primeira conexão e passa a exigir a mesma. Se o volume do Core for apagado, os agentes recusam o Core
  novo: apague também o volume `komodo-periphery-keys` deles e refaça o onboarding.
- **Backup.** Banco no volume `komodo-mongo-data`; backups datados em `/etc/komodo/backups` (ver
  [docs](https://komo.do/docs/setup/backup)).
- **Mongo 5+ exige CPU com AVX.** Se o servidor do Core não tiver, troque para o FerretDB (`compose/ferretdb.compose.yaml` oficial).

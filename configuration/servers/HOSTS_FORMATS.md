# Formatos do `hosts.ini`

Um modelo por servidor, pronto para copiar. Vai em dois lugares do GitHub (ver [README](../../README.md#deploy-pelo-github-actions)):
a secret `ANSIBLE_HOSTS_INI` do Environment do servidor e a secret `<SERVIDOR>_ANSIBLE_HOSTS_INI`. Para rodar
local, salve em `configuration/servers/<servidor>/hosts.ini` (ignorado pelo git).

Cada servidor é **uma linha só** sob `[servers]`. Variáveis não secretas ficam no `vars.yml` de cada pasta.

## ops

```ini
[servers]
IP_DO_OPS ansible_user=root ansible_ssh_forward_agent=true server=ops domain=grupoazuos.com.br email=infra@grupoazuos.com.br netbird_setup_key="SETUP_KEY_DO_NETBIRD" netbird_mgmt_url=https://netbird.grupoazuos.com.br grafana_admin_password="SENHA_GRAFANA" komodo_admin_password="SENHA_KOMODO" komodo_onboarding_key=""
```

## core

```ini
[servers]
IP_DO_CORE ansible_user=root ansible_ssh_forward_agent=true server=core domain=grupoazuos.com.br email=infra@grupoazuos.com.br netbird_setup_key="SETUP_KEY_DO_NETBIRD" netbird_mgmt_url=https://netbird.grupoazuos.com.br komodo_onboarding_key=""
```

## crm

```ini
[servers]
IP_DO_CRM ansible_user=root ansible_ssh_forward_agent=true server=crm domain=grupoazuos.com.br email=infra@grupoazuos.com.br netbird_setup_key="SETUP_KEY_DO_NETBIRD" netbird_mgmt_url=https://netbird.grupoazuos.com.br komodo_onboarding_key=""
```

## flow

```ini
[servers]
IP_DO_FLOW ansible_user=root ansible_ssh_forward_agent=true server=flow domain=grupoazuos.com.br email=infra@grupoazuos.com.br netbird_setup_key="SETUP_KEY_DO_NETBIRD" netbird_mgmt_url=https://netbird.grupoazuos.com.br komodo_onboarding_key=""
```

## Variáveis

| Variável | Servidores | Para quê |
|---|---|---|
| `server` | todos | Nome do servidor: vira o grupo e escolhe o `vars.yml` |
| `domain`, `email` | todos | Domínio base e contato do ACME |
| `netbird_setup_key` | todos | Setup Key do painel `https://netbird.<domain>` (a mesma nos 4) |
| `netbird_mgmt_url` | todos | Endereço do NetBird |
| `komodo_onboarding_key` | todos | Vazia na primeira subida. Depois da etapa `komodo`, crie em **Settings → Onboarding** no painel do ops e use a mesma nos 4 |
| `vpn_ip` | todos | *(Opcional)* IP no NetBird; sem ele, é lido da `wt0` |
| `komodo_admin_password` | ops | Senha do `admin` do Komodo (`openssl rand -base64 24`) |
| `grafana_admin_password` | ops | Senha do `admin` do Grafana (`openssl rand -base64 24`) |

**SSH fechado no firewall:** troque `IP_DO_<SERVIDOR>` pelo IP do NetBird e cadastre `NETBIRD_CI_SETUP_KEY`.

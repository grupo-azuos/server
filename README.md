# server

Servidor prod (borda pública com Coolify + NetBird) que publica o servidor homo pelo túnel da VPN.

```text
usuário ─▶ DNS *.homo.<domain> ─▶ prod
        ─▶ Traefik do Coolify do prod: escolhe pelo SNI, não abre o TLS (passthrough)
        ─▶ túnel NetBird ─▶ homo 100.x.y.z:443
        ─▶ Traefik do Coolify do homo: TLS com o certificado do app ─▶ app
```

Quem emite os certificados de `*.homo` é o Coolify do homo, como em qualquer app. Não precisa de API de DNS
nem de lista de hosts no prod: criou o app no homo com `https://app.homo.<domain>`, ele já responde.
O desafio do Let's Encrypt é o TLS-ALPN (porta 443), o único que atravessa o passthrough.

```text
```

| Servidor | Roda | Docs |
|---|---|---|
| `prod` | VPS pública: Coolify, NetBird server + dashboard, agente NetBird, RustDesk | [servers/prod](configuration/servers/prod/README.md) |
| `homo` | Homologação: Coolify, agente NetBird, Supabase self-hosted | [servers/homo](configuration/servers/homo/README.md) |
| `automacao` | Automações: agente NetBird, exporters | [servers/automacao](configuration/servers/automacao/README.md) |
| `crm` | CRM: agente NetBird, exporters | [servers/crm](configuration/servers/crm/README.md) |
| `internos` | Sistemas internos: agente NetBird, exporters | [servers/internos](configuration/servers/internos/README.md) |
| `monitoramento` | Painel do Komodo, Prometheus + Grafana (só pela VPN), agente NetBird, exporters | [servers/monitoramento](configuration/servers/monitoramento/README.md) |

Todos entram no NetBird. Os exporters (node-exporter + cAdvisor) rodam em todos, menos no prod, e o
Prometheus do `monitoramento` coleta os dados pela VPN: [apps/monitoring](configuration/apps/monitoring/README.md).
O agente do Komodo também roda em todos, menos no prod, e o painel fica no `monitoramento`: [apps/komodo](configuration/apps/komodo/README.md).
Cada um tem um Caddy (borda com TLS automático; no homo, atrás da borda pela VPN), com as rotas em
`configuration/servers/<servidor>/vars.yml`: [apps/caddy](configuration/apps/caddy/README.md).

**Os 5 de uma vez** (docker, netbird-client, exporters, monitoring, komodo, komodo-periphery e caddy, nessa ordem):

```bash
ansible-playbook configuration/ansible/deploy.yml --tags servidores
```

Na primeira vez a onboarding key ainda não existe (ela é criada no painel do Komodo), então os agentes sobem
mas não entram no painel. Crie a chave em **Settings → Onboarding**, preencha `komodo_onboarding_key` nos
`hosts.ini` e rode de novo: as etapas já feitas não mudam nada.

## Preparação (uma vez)

```bash
brew install ansible             # ou: sudo dnf install ansible-core
cp configuration/servers/prod/inventory.ini configuration/servers/prod/hosts.ini
cp configuration/servers/homo/inventory.ini configuration/servers/homo/hosts.ini
# servidores novos: o mesmo para automacao, crm, internos e monitoramento
```

Preencha os `hosts.ini` (ignorados pelo git): IP, usuário, domínio e segredos de cada servidor, no mesmo
formato do my-config (`[servers]` + uma linha por host). A variável `server=` de cada linha vira
o grupo de mesmo nome (`configuration/servers/groups.yml`), e o grupo `monitorados` diz quem é monitorado. Variáveis não secretas comuns (versões,
caminhos, faixa da VPN) ficam no `vars:` de `configuration/ansible/deploy.yml`.

| Pasta | Conteúdo |
|---|---|
| `configuration/ansible/` | `deploy.yml` e `clean.yml`: chamam as tasks dos apps por tag |
| `configuration/apps/<app>/` | `compose.yml`, `config/` e `ansible/deploy.*.yml` / `clean.*.yml` de cada app |
| `configuration/apps/coolify/README.md` | Proxy do Traefik, modelo de labels, diagnóstico e histórico de correções |
| `configuration/servers/<servidor>/` | `hosts.ini` (real, fora do git), `inventory.ini` (modelo) e README |

Todos os comandos rodam da raiz do repo; o `ansible.cfg` já carrega todos os inventários (um `hosts.ini` que ainda não existe só gera aviso).

**Commits:** formato `[tipo](local): Mensagem`, igual ao template da casa (tipos e locais em `.gitmessage`). Uma vez
por clone:

```bash
git config core.hooksPath .githooks     # recusa commit fora do padrão
git config commit.template .gitmessage  # mostra o modelo no editor
```
Só um servidor: acrescente `--limit <servidor>` (`prod`, `homo`, `automacao`, `crm`, `internos`, `monitoramento`).

## Etapas

Rode uma por vez, confira e só então siga.

### 1. DNS (manual)

No provedor de DNS, os dois registros apontam para o IP público do prod:

| Tipo | Nome | Valor |
|---|---|---|
| A | `netbird` | IP do prod |
| A | `*.homo` | IP do prod |

Na Cloudflare, use "DNS only" (nuvem cinza).

Conferir: `dig +short netbird.<domain>` e `dig +short teste.homo.<domain>` devolvem o IP do prod,
e `ansible all -m ping` responde `pong` nos dois.

### 2. Coolify

```bash
ansible-playbook configuration/ansible/deploy.yml --tags coolify
```

Instala o Coolify nas duas máquinas pelo instalador oficial e confere se o `coolify-proxy` (Traefik) subiu.
Conferir: painel em `http://<ip>:8000` nas duas, e o admin criado.

### 3. NetBird server + dashboard

Duas formas; o passo a passo das duas está em [apps/netbird](configuration/apps/netbird/README.md):

- **Pelo Coolify:** colar `configuration/apps/netbird/compose.coolify.yml` como recurso Docker Compose.
- **Direto no Docker (Ansible):**
  ```bash
  ansible-playbook configuration/ansible/deploy.yml --tags netbird
  ```
  Sobe `configuration/apps/netbird/compose.yml` em `/opt/netbird`.

As duas usam o Traefik do Coolify, com o `readTimeout` desligado (senão os streams gRPC caem a cada 60s).
Conferir: `https://netbird.<domain>` abre o painel.

### 4. Admin e Setup Key (manual)

1. No painel, crie o usuário admin.
2. Em **Setup Keys**, crie uma chave reutilizável.
3. Coloque a chave em `netbird_setup_key` no `hosts.ini` dos dois servidores.

### 5. Agentes NetBird

```bash
ansible-playbook configuration/ansible/deploy.yml --tags netbird-client
```

Conferir: as duas máquinas aparecem em **Peers** e `netbird status` mostra `Management: Connected`.

### 6. Túnel

- **homo (pelo painel, sem SSH):** no proxy do Coolify do homo, troque o desafio ACME para TLS-ALPN e aceite
  PROXY protocol da faixa da VPN. Preencha o Wildcard domain com `https://homo.<domain>`. Os passos estão em
  [apps/coolify](configuration/apps/coolify/README.md#ajustes-no-proxy).
- **prod:** testa se o homo responde na 443 pelo túnel e grava `/data/coolify/proxy/dynamic/homo.yaml`
  (passthrough por SNI na 443 e redirect para https na 80):
  ```bash
  ansible-playbook configuration/ansible/deploy.yml --tags tunnel --limit prod -e homo_vpn_ip=<IP do homo no NetBird>
  ```

### 7. App de teste

1. No Coolify do **homo**, crie um app (por exemplo a imagem `traefik/whoami`).
2. Use o domínio com **`https://`**: `https://teste.homo.<domain>`. O Coolify do homo emite o certificado
   no primeiro acesso (alguns segundos).

Conferir:

```bash
curl -I https://teste.homo.<domain>    # 200, certificado emitido para teste.homo
curl https://teste.homo.<domain>       # whoami: X-Real-Ip / X-Forwarded-For com o IP real do cliente
```

Se quiser, feche as portas 80/443 públicas do homo no firewall; o tráfego (e o desafio ACME) chega só pelo túnel.

### 8. Servidores novos e monitoramento

Para `automacao`, `crm`, `internos` e `monitoramento` (sem Coolify): Docker, agente NetBird (com a mesma Setup
Key) e exporters. Depois, Prometheus + Grafana no monitoramento:

```bash
ansible-playbook configuration/ansible/deploy.yml --tags docker
ansible-playbook configuration/ansible/deploy.yml --tags netbird-client
ansible-playbook configuration/ansible/deploy.yml --tags exporters
ansible-playbook configuration/ansible/deploy.yml --tags monitoring --limit monitoramento
```

A etapa `coolify` agora só roda no prod e no homo. Detalhes e dashboards: [apps/monitoring](configuration/apps/monitoring/README.md).
Conferir: `http://<IP do monitoramento no NetBird>:9090/targets` com todos `UP`, e o Grafana em `:3000`.

### 9. Komodo

Painel no `monitoramento` (com `komodo_admin_password`), onboarding key criada nele, depois os agentes:

```bash
ansible-playbook configuration/ansible/deploy.yml --tags komodo --limit komodo_core
# no painel: Settings → Onboarding → nova chave em komodo_onboarding_key nos hosts.ini
ansible-playbook configuration/ansible/deploy.yml --tags komodo-periphery
```

Conferir: `http://<IP do monitoramento no NetBird>:9120`, com todos os servidores em **Servers**. Domínios vêm do Caddy
de cada servidor; detalhes em [apps/komodo](configuration/apps/komodo/README.md).

## Cuidados

- **Ajustes no proxy do Coolify.** As etapas 3 e 6 alteram o proxy (`readTimeout` no prod; TLS-ALPN e PROXY protocol
  no homo). Se alguém usar "Reset configuration" no painel do Coolify, refaça os ajustes conforme
  [apps/coolify](configuration/apps/coolify/README.md#ajustes-no-proxy).
- **Labels por app.** Cada app define os próprios middlewares do Traefik, sem `@docker` de outro container. Veja o
  modelo e o diagnóstico em [apps/coolify](configuration/apps/coolify/README.md#labels-cada-app-com-as-suas).
- **Homo sem SSH.** O homo é alterado só pelo painel do Coolify.
- **Chaves do RustDesk.** O `id_ed25519` do `hbbs` (prod) identifica o servidor para todos os clientes. Faça backup
  do volume; detalhes em [apps/rustdesk](configuration/apps/rustdesk/README.md).
- **Configs dinâmicas.** No prod, `homo.yaml` aparece em **Servers → Proxy → Dynamic Configurations**.
  Não edite pelo painel; mude aqui e rode a etapa.
- **NetBird fora dos recursos do Coolify.** Ele é um compose próprio em `/opt/netbird`, para um redeploy
  no painel não derrubar a VPN.
- **Segredos do NetBird.** São gerados uma vez em `/opt/netbird/config.yaml` e nunca sobrescritos. Faça backup
  desse arquivo e do volume `netbird_netbird-data`.
- **Traefik v3.** As regras usam a sintaxe `HostRegexp`/`HostSNIRegexp` do Traefik v3, que é o padrão do Coolify v4.
- **HTTP/3 no homo.** O passthrough é só TCP; os navegadores usam HTTP/2 nos apps do homo.

# Supabase (self-hosted, homo)

Backend completo, com Postgres, Auth, REST, Storage e Studio, no ambiente de homologação. Os apps de produção
continuam no **Supabase Cloud** (`GrupoAzuos's Org`).

## O que está no ar hoje

| | |
|---|---|
| Onde | homo, `/opt/supabase` (Docker Compose fora do Coolify) |
| Instalado por | Ansible (tag `supabase`): deste repo (`configuration/apps/supabase`). Originalmente veio do `my-config` |
| Studio e API | `http://192.168.10.60:8001` (Kong). Studio com usuário `supabase` + `DASHBOARD_PASSWORD` |
| Postgres | `192.168.10.60:5432` |
| Segredos | `/opt/supabase/.env` no homo. Para ver sem SSH: Coolify do homo → Servers → localhost → Terminal |
| Arquivos (Storage) | volume `supabase-storage-data` (backend `file`) |

### API S3 do Storage

| | |
|---|---|
| Endpoint | `http://192.168.10.60:8001/storage/v1/s3` |
| Região | `local` (`STORAGE_REGION`) |
| Path-style | ligado (`forcePathStyle: true`) |
| Chaves | `S3_PROTOCOL_ACCESS_KEY_ID` / `S3_PROTOCOL_ACCESS_KEY_SECRET` no `/opt/supabase/.env` |

O `S3_PROTOCOL_PREFIX=/storage/v1` é obrigatório: o Kong corta esse prefixo antes de repassar ao storage, mas o cliente
assina a requisição (SigV4) com o caminho completo. A rota `/storage/v1/` do Kong não exige `apikey`, então clientes S3
passam direto.

```bash
AWS_ACCESS_KEY_ID=<id> AWS_SECRET_ACCESS_KEY=<secret> \
aws s3 ls --endpoint-url http://192.168.10.60:8001/storage/v1/s3 --region local
```

### Endpoint S3 público (links assinados)

Os apps entregam ao navegador **links assinados** do storage: o arquivo vai e volta direto entre navegador e
storage, sem passar pela API. Com o endpoint da LAN, o link não abre para quem está fora da rede interna (casa,
filial, 4G). Por isso o caminho S3 também é publicado num domínio:

| | |
|---|---|
| Endpoint público | `https://s3.homo.grupoazuos.com.br/storage/v1/s3` |
| Rota | Traefik do homo → `http://192.168.10.60:8001` (Kong) |
| Arquivo | [`config/proxy/supabase-s3.yaml`](config/proxy/supabase-s3.yaml) |
| Onde fica no servidor | Coolify do homo → Servers → localhost → Proxy → **Dynamic Configurations** → `supabase-s3.yaml` |

Só `/storage/v1/s3` é publicado; Studio, Auth e REST continuam só na LAN. Toda chamada exige assinatura SigV4 e os
buckets seguem privados.

```text
navegador ─▶ https://s3.homo.grupoazuos.com.br/storage/v1/s3/<bucket>/<chave>?X-Amz-Signature=...
          ─▶ prod (passthrough por SNI) ─▶ túnel ─▶ Traefik do homo ─▶ Kong :8001 ─▶ storage
```

**Aplicar:** em Dynamic Configurations, **+ Add**, nome `supabase-s3.yaml`, colar o conteúdo do arquivo e **Save**.
O Traefik carrega sozinho, sem restart. O certificado é emitido no primeiro acesso.

**Nos apps:** dois endereços, porque o servidor continua falando com o storage pela LAN:

```env
S3_ENDPOINT=http://192.168.10.60:8001/storage/v1/s3          # servidor: conferir, mover, ler, apagar
S3_PUBLIC_ENDPOINT=https://s3.homo.grupoazuos.com.br/storage/v1/s3   # vai dentro do link do navegador
S3_BUCKET=<bucket do app>                                    # um por app, nunca o de outro
```

**Envio direto do navegador (PUT):** o domínio do S3 é outra origem, então passa pelo plugin global de CORS do Kong
(`KONG_CORS_ORIGIN`). Com `*` já funciona; se for restringido, cada app do homo entra na lista.

**Assinatura:** o storage confere a SigV4 com o host que ele remonta a partir dos `X-Forwarded-*` do Kong. Atrás do
Traefik, o Kong não confia nesses cabeçalhos (sem `KONG_TRUSTED_IPS`), então repassa o próprio `Host`
(`s3.homo.grupoazuos.com.br`) com a porta publicada dele (`8001`, pelo `KONG_PORT_MAPS`). **Pendente de teste:**
se o link assinado para o domínio público voltar `SignatureDoesNotMatch`, o app assina com
`S3_SIGNING_HOST=s3.homo.grupoazuos.com.br:8001` (o paralegal já tem esse ajuste), ou o Kong passa a confiar no
Traefik com `KONG_TRUSTED_IPS`.

**Conferir:**

```bash
curl -sI https://s3.homo.grupoazuos.com.br/storage/v1/s3/   # resposta do storage (403/400 em XML), certificado válido
curl -sI https://s3.homo.grupoazuos.com.br/                 # 503 (catchall do Coolify): só o caminho S3 é publicado
```

Depois, no app: um envio e um download de verdade, de fora da rede interna.

### Atualizar o Supabase do homo (Ansible deste repo)

Arquivos: `compose.yml` (vira `/opt/supabase/docker-compose.yml`), `supabase.env.j2` (vira `/opt/supabase/.env`),
`config/` e `ansible/deploy.yml`. A tag é `supabase`, e só roda no host com `server=homo`.

1. **Uma vez:** complete o `configuration/servers/v1.0.0/homo/hosts.ini` com as variáveis `supabase_*` (o modelo está no
   `configuration/servers/v1.0.0/homo/hosts.ini.example`). Use os valores **atuais** do `/opt/supabase/.env`: senha ou JWT diferentes quebram o banco e as
   chaves dos apps. Só as `supabase_s3_*` são novas (`openssl rand -hex 16` / `openssl rand -hex 32`). O host continua
   `192.168.10.60`, porque as URLs usam esse nome.
2. **Ver o que muda:**
   ```bash
   ansible-playbook configuration/ansible/deploy.yml --tags supabase --limit homo --check --diff
   ```
   Só podem aparecer as linhas que você mudou. Qualquer outra linha do `.env` diferente significa que o
   `hosts.ini` não bate com o servidor.
3. **Aplicar:** o mesmo comando, sem `--check --diff`. Os containers só são recriados se algum arquivo mudou (cerca de
   1 min fora do ar). Para forçar: `-e supabase_force=true`.

Remover: `ansible-playbook configuration/ansible/clean.yml --tags supabase --limit homo`. Os volumes ficam;
`-e remove_volumes=true` apaga também o `/opt/supabase`.

## Versão para o Coolify (ainda não usada)

Os arquivos abaixo sobem o mesmo Supabase como recurso do Coolify do homo, em `https://supabase.homo.grupoazuos.com.br`.
**Não suba enquanto o `/opt/supabase` estiver rodando:** seria um segundo Supabase, com banco vazio e conflito na
porta 5432. Para migrar: `pg_dump` + cópia do volume de storage, subir este com os **mesmos** `JWT_SECRET`/`ANON_KEY`/
`SERVICE_ROLE_KEY`/chaves S3, e então desligar o antigo.

Origem: `my-config/configuration/apps/supabase`, adaptado para o Coolify (sem SSH, tudo pelo painel).

| Arquivo | Uso |
|---|---|
| `config/` | Fonte da verdade: `api/kong.yml` (gateway), `db/*.sql` (init do banco), `functions/` (Edge Functions) |
| `compose.coolify.base.yml` | Compose do Coolify com `@@include@@` apontando para `config/` |
| `build_compose_coolify.py` | Gera o `compose.coolify.yml`: embute `config/` e escapa `$` como `$$` |
| `compose.coolify.yml` | **Gerado.** É o que se cola no Coolify |
| `gerar-segredos.sh` | Gera senhas, `JWT_SECRET` e as chaves `ANON_KEY`/`SERVICE_ROLE_KEY` assinadas |

Mudou algo em `config/` ou no base? Rode `python3 build_compose_coolify.py` e faça o commit dos dois arquivos.

## Como funciona

```text
navegador/app ─▶ https://supabase.homo.grupoazuos.com.br ─▶ prod (passthrough) ─▶ túnel ─▶ Traefik do homo ─▶ kong:8000
kong ─▶ /auth/v1 → auth · /rest/v1 → rest · /storage/v1 → storage · /realtime/v1 → realtime
     ─▶ /functions/v1 → functions · /pg → meta (só service_role) · / → studio (basic auth)
```

| Serviço | Imagem | Sobe por padrão |
|---|---|---|
| db | `supabase/postgres:15.14.1.171` | sim |
| auth | `supabase/gotrue:v2.197.0` | sim |
| rest | `postgrest/postgrest:v16.3` | sim |
| storage | `supabase/storage-api:v1.77.0` (arquivos no volume `storage-data`) | sim |
| meta | `supabase/postgres-meta:v0.99.0` | sim |
| studio | `supabase/studio:2026.09.14-sha-4dd8a95` | sim |
| kong | `kong:3.9` (única entrada, com labels próprias `supabase-*`) | sim |
| realtime, imgproxy, functions | | só com `COMPOSE_PROFILES=extras` |

O Postgres não é publicado: fica em `127.0.0.1:5432` do homo. Para acessar pela VPN, defina
`POSTGRES_BIND_IP=<IP do homo no NetBird>` (hoje `100.85.230.136`).

## Deploy (painel do Coolify do homo)

1. Gere os segredos e **guarde a saída no cofre**. Eles não podem mudar depois:
   ```bash
   configuration/apps/supabase/gerar-segredos.sh
   ```
2. No Coolify do homo: **Projects → Homologação → + New → Docker Compose Empty**. Cole o `compose.coolify.yml`.
3. Em **Environment Variables**, cole a saída do passo 1. Opcionais:

   | Variável | Padrão | Para quê |
   |---|---|---|
   | `SUPABASE_HOST` | `supabase.homo.grupoazuos.com.br` | Domínio público (Kong) |
   | `SITE_URL` / `ADDITIONAL_REDIRECT_URLS` | o próprio Supabase / vazio | Para onde o Auth redireciona depois do login |
   | `COMPOSE_PROFILES` | vazio | `extras` liga realtime, imgproxy e functions |
   | `SMTP_*` | vazio | Sem SMTP, o usuário nasce confirmado (`ENABLE_EMAIL_AUTOCONFIRM=true`) |
   | `DISABLE_SIGNUP` | `true` | Cadastro público fechado |
   | `KONG_CORS_ORIGIN` | `*` | Origens permitidas na API |
   | `POSTGRES_BIND_IP` | `127.0.0.1` | IP do homo onde o Postgres escuta |

4. Deixe vazios os campos **Domains** dos serviços: o roteamento vem das labels do `kong`.
5. **Deploy**. O primeiro boot cria o banco e roda os SQL de `config/db/` (só nessa vez).

O DNS já atende: `*.homo.grupoazuos.com.br` aponta para o prod, que repassa ao homo pelo túnel.

## Conferir

```bash
curl -s https://supabase.homo.grupoazuos.com.br/auth/v1/health -H "apikey: <ANON_KEY>"   # {"version":...}
curl -s https://supabase.homo.grupoazuos.com.br/rest/v1/ -H "apikey: <ANON_KEY>"         # OpenAPI do PostgREST
```

O Studio fica em `https://supabase.homo.grupoazuos.com.br/`, com usuário `supabase` (ou `DASHBOARD_USERNAME`)
e senha `DASHBOARD_PASSWORD`.

Nos apps do homo: `SUPABASE_URL=https://supabase.homo.grupoazuos.com.br` e `SUPABASE_ANON_KEY=<ANON_KEY>`.
No backend, use `SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY>`.

## Cuidados

- **Segredos amarrados:** `ANON_KEY` e `SERVICE_ROLE_KEY` são assinadas com o `JWT_SECRET`. Se trocar o secret, gere as
  três de novo e atualize todos os apps. O `POSTGRES_PASSWORD` é gravado no banco no primeiro boot: trocá-lo depois
  exige alterar as roles no Postgres.
- **Init só na criação:** os SQL de `config/db/` rodam apenas quando o volume `db-data` é criado. Mudá-los não afeta um
  banco existente.
- **Backup:** os volumes `db-data` (banco) e `storage-data` (arquivos) do recurso no Coolify.
- **Labels:** o Kong tem as próprias (`supabase-redirect`, `supabase-headers`), como todo app
  (ver [apps/coolify](../coolify/README.md#labels-cada-app-com-as-suas)).
- **`kong.yml` sem aspas duplas:** o entrypoint do Kong expande as variáveis com `eval echo`, e aspas duplas quebram a
  expansão.
- **Hostname do Realtime:** precisa ter um ponto. O alias `realtime-dev.supabase-realtime` é usado no `kong.yml`.

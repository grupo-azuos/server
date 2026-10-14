# RustDesk Server OSS

Acesso remoto self-hosted. `hbbs` é o servidor de ID e de registro, e `hbbr` é o relay. Os dois usam a rede do
host (sem Traefik) e guardam as chaves e o banco em `/root` do container.

| Arquivo | Uso |
|---|---|
| `compose.yml` | Deploy direto no Docker (`docker compose up -d` numa pasta do servidor) |
| `.env.example` | Variáveis do compose: endereço do relay, versão e `ALWAYS_USE_RELAY` |

Origem: `~/Desktop/compose/rustdesk` (compose avulso), trazido para cá para ficar junto do resto da infra.

## Onde roda

| Servidor | Como | Containers |
|---|---|---|
| prod | Coolify, projeto **`rede`**, serviço `service-wg9evmz1juc27ny1l75w59pz` | `hbbs-myujt155j5dwuh65a7hwvvo7`, `hbbr-myujt155j5dwuh65a7hwvvo7` |

A instância do prod foi criada pelo Coolify, não por este `compose.yml` (os nomes dos containers são os do Coolify).
Os dois arquivos aqui servem de referência e para reinstalação manual.

**A confirmar no painel do prod** (Projects → rede → RustDesk) e registrar aqui:

- [ ] Endereço usado pelos clientes (`RUSTDESK_RELAY_SERVER` / argumento `-r` do `hbbs`)
- [ ] Versão da imagem `rustdesk/rustdesk-server` (fixar uma tag em vez de `latest`)
- [ ] `ALWAYS_USE_RELAY`
- [ ] Volume onde ficam `id_ed25519` e `id_ed25519.pub`

## Portas

O RustDesk não passa pelo Traefik: as portas abrem direto no host do prod.

| Porta | Protocolo | Função |
|---|---|---|
| 21115 | TCP | Teste de NAT |
| 21116 | TCP e UDP | Registro, heartbeat e conexões |
| 21117 | TCP | Relay |

`21118`/`21119` (cliente web) ficam fechadas. A `21114` é do Server Pro e não é usada.

```bash
sudo ufw allow 21115:21117/tcp
sudo ufw allow 21116/udp
```

O registro DNS do endereço dos clientes aponta para o IP do prod. Na Cloudflare, use "DNS only".

## Deploy direto no Docker (alternativa ao Coolify)

```bash
cp .env.example .env       # ajuste RUSTDESK_RELAY_SERVER=<endereço>:21117
docker compose config --quiet
docker compose up -d
```

## Configurar os clientes

Chave pública:

```bash
docker exec <container hbbs> cat /root/id_ed25519.pub   # no prod: hbbs-myujt155j5dwuh65a7hwvvo7
```

No RustDesk, em **Configurações → Rede → Servidor ID/Relay**:

- **Servidor ID:** o endereço do servidor (sem porta)
- **Servidor Relay:** `<endereço>:21117`
- **Key:** o conteúdo de `id_ed25519.pub`
- **Servidor API:** vazio

## Cuidados

- **Chaves:** são geradas na primeira inicialização. Se `id_ed25519` se perder, todos os clientes precisam receber a
  chave nova. Faça backup do volume do `hbbs`.
- **Rede do host:** o Traefik não enxerga o RustDesk e as labels não se aplicam. Só firewall e DNS.

Documentação oficial:

- https://rustdesk.com/docs/en/self-host/rustdesk-server-oss/docker/
- https://rustdesk.com/docs/en/self-host/client-configuration/

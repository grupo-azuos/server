# Caddy: proxy de todos os servidores

Mesmo modelo do `.host.` do my-config: a Cloudflare só resolve o nome (nuvem cinza), o Caddy da borda emite o
certificado (Let's Encrypt, automático) e entrega o app, ou repassa pela VPN quando o app está em outro servidor.

```text
usuário ─▶ Cloudflare (só DNS) ─▶ Caddy de borda (TLS) ─┬─▶ app neste servidor (rede docker `caddy`)
                                                         └─▶ NetBird ─▶ Caddy local do homo (HTTP) ─▶ app
```

| Modo | Onde | Portas | TLS |
|---|---|---|---|
| `edge` | ops, core, crm, auto | `80`, `443` (tcp/udp) | sim, automático |
| `local` | homo | `<IP NetBird>:8088` (`caddy_tunnel_port`) | não: chega pronto da borda |

## Rotas

Ficam em `configuration/servers/<versão>/<servidor>/vars.yml`, na lista `caddy_routes`. O Ansible gera
`/opt/caddy/config/conf.d/routes.caddy`:

```yaml
caddy_mode: edge
caddy_routes:
  - hosts: ["app.{{ domain }}"]          # app neste servidor
    upstream: app:3000                   # container:porta na rede docker `caddy`
  - hosts: ["app.homo.{{ domain }}"]     # app no homo: repassa pela VPN
    server: homo
  - hosts: ["komodo.{{ domain }}"]       # só um caminho público
    path: /listener/*
    upstream: "{{ vpn_ip }}:9120"
```

**App na homologação:** são duas rotas com o mesmo nome. Na borda (`ops`), `server: homo`; no `homo`,
`upstream: app:3000`. E um registro A `app.homo` na Cloudflare, só DNS, com o IP da borda.

**App em produção:** uma rota no servidor onde ele roda, e um registro A com o IP daquele servidor.

O container do app precisa estar na rede `caddy` (no compose: `networks: [caddy]`, com `caddy: {external: true}`).

## Deploy

```bash
ansible-playbook configuration/ansible/deploy.yml --tags caddy                 # todos
ansible-playbook configuration/ansible/deploy.yml --tags caddy --limit crm     # só um
```

Antes de recarregar, o Ansible roda `caddy validate`; uma config inválida para ali e não derruba o que está no ar.

## Cuidados

- **Só nomes listados.** O Caddy só emite certificado para os `hosts` das rotas, então ninguém força a
  emissão para subdomínios aleatórios. Não use `on_demand_tls` sem um `ask`.
- **Portas 80/443 abertas** na borda, para o Let's Encrypt validar.
- **Homo e Coolify.** No homo, o Coolify ocupa 80, 443 e 8080; por isso o Caddy local usa a 8088, só no IP do NetBird.
- **IP real do usuário.** A borda manda `X-Forwarded-For`; o Caddy local só confia nele vindo da faixa da VPN.
- **Certificados** no volume `caddy-data`. `clean` com `-e remove_volumes=true` apaga, e o Caddy pede de novo.

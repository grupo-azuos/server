# Cockpit: painel do sistema de cada servidor

[Cockpit](https://cockpit-project.org) instalado pelo pacote do sistema (não container), porque administra o
próprio host: serviços, logs, disco, rede, atualizações e terminal.

- **Só pela VPN:** o `cockpit.socket` escuta só no IP do NetBird, porta `cockpit_port` (padrão `9091`; a `9090` é
  do Prometheus no ops). Nada no IP público.
- **Acesso:** `https://<IP NetBird>:9091`, com o usuário do sistema (certificado autoassinado).
- **Onde roda:** grupo `cockpit` em [`servers/groups.yml`](../../servers/groups.yml).

```bash
ansible-playbook configuration/ansible/deploy.yml --tags cockpit --limit ops
ansible-playbook configuration/ansible/clean.yml --tags cockpit --limit ops
```

No Rocky o `root` é bloqueado no Cockpit (`/etc/cockpit/disallowed-users`): entre com um usuário que tenha
senha e esteja no grupo `wheel` (`useradd -m -G wheel <nome> && passwd <nome>`).

#!/usr/bin/env python3
"""Gera compose.coolify.yml a partir de compose.coolify.base.yml.

Cada linha `@@include <arquivo>@@` vira o conteúdo do arquivo (relativo a esta pasta), com a mesma indentação
e com `$` trocado por `$$`. No compose, `$$` é um `$` literal; sem o escape, o docker compose tentaria
interpolar `$SUPABASE_ANON_KEY` (kong.yml) e `$JWT_SECRET` (jwt.sql) no momento do deploy.

Rode depois de mudar qualquer arquivo de config/:  python3 build_compose_coolify.py
"""
import re
from pathlib import Path

HERE = Path(__file__).parent
INCLUDE = re.compile(r"^(?P<indent>\s*)@@include (?P<path>\S+)@@\s*$")
HEADER = (
    "# GERADO por build_compose_coolify.py a partir de compose.coolify.base.yml e config/. Não edite à mão.\n"
    "# Cole este arquivo no Coolify do homo (veja o README).\n"
)


def expand(line: str) -> str:
    match = INCLUDE.match(line)
    if not match:
        return line
    indent = match["indent"]
    text = (HERE / match["path"]).read_text().replace("$", "$$")
    return "".join(f"{indent}{l}".rstrip() + "\n" for l in text.splitlines())


def main() -> None:
    base = (HERE / "compose.coolify.base.yml").read_text().splitlines(keepends=True)
    body = [l for l in base if not l.startswith("# Fonte do compose") and "build_compose_coolify.py, que gera" not in l]
    out = HEADER + "".join(expand(l) for l in body)
    (HERE / "compose.coolify.yml").write_text(out)
    print(f"compose.coolify.yml: {out.count(chr(10))} linhas")


if __name__ == "__main__":
    main()

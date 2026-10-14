#!/usr/bin/env bash
# Gera os segredos do Supabase, prontos para colar em Environment Variables do recurso no Coolify.
# ANON_KEY e SERVICE_ROLE_KEY são JWTs HS256 assinados com o JWT_SECRET gerado aqui: os três andam juntos.
# Rode UMA vez e guarde a saída no cofre de senhas. Trocar depois exige recriar as chaves de todos os clientes.
set -euo pipefail

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

jwt() { # $1 = role, $2 = secret
  local now exp header payload sig
  now=$(date +%s)
  exp=$((now + 10 * 365 * 24 * 3600))
  header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"role":"%s","iss":"supabase","iat":%d,"exp":%d}' "$1" "$now" "$exp" | b64url)
  sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$2" -binary | b64url)
  printf '%s.%s.%s' "$header" "$payload" "$sig"
}

jwt_secret=$(openssl rand -hex 32)

cat <<EOF
POSTGRES_PASSWORD=$(openssl rand -hex 24)
JWT_SECRET=${jwt_secret}
ANON_KEY=$(jwt anon "$jwt_secret")
SERVICE_ROLE_KEY=$(jwt service_role "$jwt_secret")
DASHBOARD_PASSWORD=$(openssl rand -hex 16)
SECRET_KEY_BASE=$(openssl rand -hex 32)
REALTIME_ENC_KEY=$(openssl rand -hex 8)
S3_PROTOCOL_ACCESS_KEY_ID=$(openssl rand -hex 16)
S3_PROTOCOL_ACCESS_KEY_SECRET=$(openssl rand -hex 32)
EOF

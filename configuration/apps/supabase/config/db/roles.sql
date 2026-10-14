-- Define a senha das roles internas do Supabase a partir de $POSTGRES_PASSWORD.
-- Usa \gexec para so alterar roles que realmente existem na imagem,
-- assim o init nao quebra se uma versao do supabase/postgres mudar o conjunto.
\set pgpass `echo "$POSTGRES_PASSWORD"`

select format('alter role %I with password %L', rolname, :'pgpass')
from pg_roles
where rolname in (
  'supabase_admin',
  'authenticator',
  'pgbouncer',
  'supabase_auth_admin',
  'supabase_functions_admin',
  'supabase_storage_admin',
  'supabase_read_only_user'
)
\gexec

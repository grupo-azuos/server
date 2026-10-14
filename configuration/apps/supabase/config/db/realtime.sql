-- Schema onde o servico Realtime guarda tenants e subscriptions.
create schema if not exists _realtime;
alter schema _realtime owner to supabase_admin;

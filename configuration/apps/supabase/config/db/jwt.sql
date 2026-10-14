-- Publica o segredo JWT dentro do banco: e assim que o PostgREST e as
-- funcoes auth.uid() / auth.role() validam o token de cada request.
\set jwt_secret `echo "$JWT_SECRET"`
\set jwt_exp `echo "$JWT_EXP"`

alter database postgres set "app.settings.jwt_secret" to :'jwt_secret';
alter database postgres set "app.settings.jwt_exp" to :'jwt_exp';

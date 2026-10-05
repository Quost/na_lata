#!/usr/bin/env bash
# Guardas estáticas do PR: falha ao violar regras do AGENTS.md.
set -u
fail=0
err() { echo "::error::$1"; fail=1; }

# 1. Segredos/chaves administrativas no cliente
if grep -rniE "service_role|sb_secret_|SUPABASE_SERVICE" lib tool android config pubspec.yaml 2>/dev/null; then
  err "Chave administrativa/service_role não pode aparecer no app."
fi
if grep -rnE "eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\." lib test tool config 2>/dev/null; then
  err "Possível JWT/token embutido no código."
fi
# 2. Widgets não acessam Supabase/HTTP diretamente
if grep -rnE "Supabase\.instance|supabase_flutter|package:http/" lib --include=*.dart \
  | grep -vE "^lib/(core|data)/|^lib/main\.dart"; then
  err "Acesso direto a Supabase/HTTP fora de repositórios/clientes."
fi
# 3. Segredos de arquivo local
git ls-files | grep -E "(^|/)(\.env.*|.*\.jks|.*\.keystore|key\.properties|local\.properties|google-services\.json)$" \
  | grep -v "\.example" && err "Arquivo local/segredo versionado."
# 4. Migrations: nome ordenado e sem comandos destrutivos sem aviso
for f in supabase/migrations/*.sql; do
  [[ "$(basename "$f")" =~ ^[0-9]{12,14}_[a-z0-9_]+\.sql$ ]] || err "Nome de migration inválido: $f"
  if grep -niE "drop (table|schema|column)|truncate" "$f" | grep -viE "if exists|-- allow-destructive" ; then
    err "Comando destrutivo em $f (use '-- allow-destructive' com aprovação do professor)."
  fi
  if grep -qiE "create table" "$f" && ! grep -qiE "enable row level security" "$f"; then
    err "$f cria tabela sem habilitar RLS."
  fi
done
# 5. Skips de teste
if grep -rnE "skip:\s*true|@Skip|\bfocus\b.*test" test 2>/dev/null; then
  err "Testes ignorados não são permitidos."
fi
exit $fail

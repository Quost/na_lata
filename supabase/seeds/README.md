# Fixtures do Supabase local

Executados em ordem alfabética por `supabase db reset` e por `dart run tool/local_supabase.dart seed`. **Somente local**: nunca rodar no SQL Editor do projeto da turma.

| Arquivo | Conteúdo |
|---|---|
| `000_accounts.sql` | contas A/B (apaga e recria; o cascade limpa os dados delas) |
| `100_catalog.sql` | 5 produtos `200…` (upsert) |
| `200_reviews.sql` | avaliações de A e B |
| `300_community.sql` | favoritos, relatos em cidades de SC, denúncia de B |
| `400_lists.sql` | lista privada e lista pública de A |

IDs fixos para usar em testes:

- Usuários: A `aaaaaaaa-0000-4000-8000-00000000000a`, B `bbbbbbbb-0000-4000-8000-00000000000b`.
- Produtos: `2000000000011` (avaliado por A e B), `2000000000028`, `2000000000035`, `2000000000042`, `2000000000059` (sem avaliações).
- Prefixos: reviews `c000…`, sightings `d000…`, reports `e000…`, listas `f000…`.

## Acrescentar fixtures da sua feature

1. Crie `NNN_sua_feature.sql` com número livre depois das dependências (ex.: `450_brands.sql`). Não edite o arquivo de outra feature sem combinar.
2. Repetir o seed precisa dar o mesmo estado: dados de A/B são recriados automaticamente; para tabelas próprias use IDs fixos e `on conflict … do update`, ou apague antes as linhas da fixture.
3. Datas fixas (não `now()`) quando o teste depende de ordem.
4. Se a feature tem migração nova, ela entra em `supabase/migrations/` com versão única (o CLI recusa duas migrações com a mesma data/número).
5. Rode `reset`, `seed` duas vezes e `check` antes do PR.

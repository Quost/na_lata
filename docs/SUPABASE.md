# Supabase — preparação do professor

1. Criar projeto exclusivo para a aula no Supabase. Não reutilizar banco de produção.
2. Abrir SQL Editor e executar `supabase/migrations/202609280001_classroom.sql` **uma vez**. A migração é transacional e não apaga tabelas existentes. Em seguida, aplique as migrações posteriores em ordem de data (ex.: `202610050001_product_lists.sql`, listas de produtos; `202610050002_public_profile.sql`, bio e leitura de perfil por coluna; `202610060001_moderation.sql`, moderação).
3. Em Authentication → Sign In / Providers, habilitar **Anonymous Sign-Ins**. Os caminhos do painel podem variar.
4. Copiar a URL e a chave pública `sb_publishable_...`. O launcher desta turma exige esse formato; chaves legadas JWT não são aceitas. **Nunca usar service_role ou secret no app.**
5. Preparar configuração local:

```sh
cp config/classroom.example.json config/classroom.json
# Preencher URL e chave pública no JSON.
flutter run --dart-define-from-file=config/classroom.json
```

Esse JSON está ignorado pelo Git. Distribua a configuração à turma. A chave pública não concede acesso administrativo: permissões e RLS continuam obrigatórias.

O arquivo local desta máquina já está preenchido com a URL/chave fornecidas. Envie **config/classroom.json** aos alunos e o link do [tutorial](ALUNOS.md). Ele cumpre o papel de configuração por ambiente, carregada no build pelo Flutter; não é necessário adicionar dotenv ou embutir um `.env` como asset.

Para conferir o serviço: `dart run tool/check_supabase.dart`. Depois de habilitar o login anônimo e aplicar a migração, use `dart run tool/check_supabase.dart --session` para criar um usuário de diagnóstico e confirmar perfil e leitura das tabelas. Não publica avaliações; o usuário criado permanece no Auth para inspeção pelo professor. O comando não imprime chaves nem tokens.

Uma resposta 401 em `/rest/v1/` sem sessão não prova que a chave é inválida. O diagnóstico verifica primeiro `/auth/v1/settings` e, quando solicitado, uma sessão real; tabelas da aula exigem usuário autenticado.

A identidade anônima persiste no aparelho. Reinstalar/limpar armazenamento cria nova identidade, sem recuperar avaliações anteriores. Não usar apelido como autorização. Para uso público após a aula, revisar autenticação, CAPTCHA e limites; este projeto foi pensado para uma turma controlada.

## Quem pode fazer o quê

- Usuário autenticado (inclusive anônimo): ler catálogo, perfis/apelidos, avaliações e relatos.
- Importar produto novo sem editar cadastro de outros.
- Criar, editar e excluir suas próprias avaliações.
- Ler/escrever seus próprios favoritos e denúncias.
- Listas de produtos: dono lê/edita/exclui; lista pública é legível por qualquer usuário autenticado. Criar lista ou adicionar item exige conta confirmada (não anônima).
- Alterar somente apelido e bio do próprio perfil; registrar relatos como o próprio usuário.
- Perfis: só `id`, `nickname` e `bio` são legíveis. Colunas novas em `profiles` nascem sem leitura nem edição pelo app.
- Denúncia nasce como pending; só moderador decide (ver Moderação).
- Cliente sem sessão: sem acesso às tabelas.

## Validar depois de configurar

Aplicar SQL, iniciar o app duas vezes em instalações distintas e confirmar dois usuários e dois profiles. Após T02/T08: importar código real, avaliar em A e ler em B; tentar alterar/deletar a avaliação de A usando B (deve afetar zero linhas/ser negado). Testar nota 0/6, 501 caracteres e duplicidade. Executar ainda `supabase/tests/rls_smoke.sql`, `supabase/tests/lists_rls.sql` e `supabase/tests/profiles_rls.sql` no SQL Editor; o script usa transação e desfaz todos os dados criados.

Sem projeto configurado, somente o modo demo pode ser validado. Não confundir erro de permissão com uma lista vazia e não substituir banco por fake silenciosamente.

Fontes: [Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [sessões anônimas](https://supabase.com/docs/guides/auth/auth-anonymous), [chaves](https://supabase.com/docs/guides/api/api-keys).

## Moderação (MOD01)

Aplicar `supabase/migrations/202610060001_moderation.sql` uma vez, depois da migração da turma. **Aplicar antes de publicar o app atualizado:** a lista de avaliações passa a filtrar `visibility`.

Promover o professor (SQL Editor, como postgres; o id está em Authentication → Users):

```sql
insert into public.moderators(user_id) values ('UUID-DO-PROFESSOR');
-- remover: delete from public.moderators where user_id = 'UUID-DO-PROFESSOR';
```

O cliente não tem nenhum privilégio em `moderators`: ninguém se promove pelo app.

| Quem | Avaliação visível | Avaliação oculta | Denúncias | Trilha `moderation_log` |
|---|---|---|---|---|
| Usuário comum | lê | não lê | lê/cria só as próprias | não lê |
| Autor da avaliação | lê, edita, exclui | lê, edita e exclui a própria; não restaura | idem | não lê |
| Moderador | lê | lê | lê a fila global; decide só por função | lê |

- Ocultar/restaurar: `moderate_review(review_id, hidden, motivo)`. Ocultar marca as denúncias pendentes daquela avaliação como `actioned`.
- Arquivar sem ocultar: `dismiss_report(report_id, motivo)` → `dismissed`.
- As funções conferem `auth.uid()` no servidor, exigem motivo (3–500 caracteres) e retornam `ok`, `unchanged` ou `not_found`.
- Ocultar não apaga autoria, nota nem comentário. A lista pública e as estatísticas ignoram ocultas.
- Cada decisão grava ator, data, motivo, alvo e autor da avaliação em `moderation_log`. A tabela é imutável: update e delete são barrados por trigger, inclusive para o dono do banco. Ela não tem FK, então sobrevive à exclusão do conteúdo.
- Denúncias antigas com status `reviewed` viram `dismissed` sem ator (não havia registro de quem decidiu).

Validar com `supabase/tests/moderation_test.sql` (cria usuários A, B e moderador, testa autopromoção, fila, ocultar/restaurar e trilha; desfaz tudo) e repetir `rls_smoke.sql` como regressão.

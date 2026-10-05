# Supabase — preparação do professor

1. Criar projeto exclusivo para a aula no Supabase. Não reutilizar banco de produção.
2. Abrir SQL Editor e executar `supabase/migrations/202609280001_classroom.sql` **uma vez**. A migração é transacional e não apaga tabelas existentes. Em seguida, aplique as migrações posteriores em ordem de data (ex.: `202610050001_product_lists.sql`, listas de produtos).
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
- Alterar somente seu apelido; registrar relatos como o próprio usuário.
- Denúncia nasce como pending; só professor pelo Dashboard administra status.
- Cliente sem sessão: sem acesso às tabelas.

## Validar depois de configurar

Aplicar SQL, iniciar o app duas vezes em instalações distintas e confirmar dois usuários e dois profiles. Após T02/T08: importar código real, avaliar em A e ler em B; tentar alterar/deletar a avaliação de A usando B (deve afetar zero linhas/ser negado). Testar nota 0/6, 501 caracteres e duplicidade. Executar ainda `supabase/tests/rls_smoke.sql` e `supabase/tests/lists_rls.sql` no SQL Editor; o script usa transação e desfaz todos os dados criados.

Para testar permissões sem tocar no projeto da turma, use o Supabase local com contas A/B: [LOCAL.md](LOCAL.md).

Sem projeto configurado, somente o modo demo pode ser validado. Não confundir erro de permissão com uma lista vazia e não substituir banco por fake silenciosamente.

Fontes: [Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [sessões anônimas](https://supabase.com/docs/guides/auth/auth-anonymous), [chaves](https://supabase.com/docs/guides/api/api-keys).

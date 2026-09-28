# Supabase — preparação do professor

1. Criar projeto exclusivo para a aula no Supabase. Não reutilizar banco de produção.
2. Abrir SQL Editor e executar `supabase/migrations/202609280001_classroom.sql` **uma vez**. A migração é transacional e não apaga tabelas existentes.
3. Em Authentication → Sign In / Providers, habilitar **Anonymous Sign-Ins**. Os caminhos do painel podem variar.
4. Copiar a URL e a chave pública/publishable (a chave anon legada também funciona). **Nunca usar service_role ou secret no app.**
5. Preparar configuração local:

```sh
cp config/classroom.example.json config/classroom.json
# Preencher URL e chave pública no JSON.
flutter run --dart-define-from-file=config/classroom.json
```

Esse JSON está ignorado pelo Git. Distribua a configuração à turma. A chave pública não concede acesso administrativo: permissões e RLS continuam obrigatórias.

A identidade anônima persiste no aparelho. Reinstalar/limpar armazenamento cria nova identidade, sem recuperar avaliações anteriores. Não usar apelido como autorização. Para uso público após a aula, revisar autenticação, CAPTCHA e limites; este projeto foi pensado para uma turma controlada.

## Quem pode fazer o quê

- Usuário autenticado (inclusive anônimo): ler catálogo, perfis/apelidos, avaliações e relatos.
- Importar produto novo sem editar cadastro de outros.
- Criar, editar e excluir suas próprias avaliações.
- Ler/escrever seus próprios favoritos e denúncias.
- Alterar somente seu apelido; registrar relatos como o próprio usuário.
- Denúncia nasce como pending; só professor pelo Dashboard administra status.
- Cliente sem sessão: sem acesso às tabelas.

## Validar depois de configurar

Aplicar SQL, iniciar o app duas vezes em instalações distintas e confirmar dois usuários e dois profiles. Após T02/T08: importar código real, avaliar em A e ler em B; tentar alterar/deletar a avaliação de A usando B (deve afetar zero linhas/ser negado). Testar nota 0/6, 501 caracteres e duplicidade. Executar ainda `supabase/tests/rls_smoke.sql` no SQL Editor; o script usa transação e desfaz todos os dados criados.

Sem projeto configurado, somente o modo demo pode ser validado. Não confundir erro de permissão com uma lista vazia e não substituir banco por fake silenciosamente.

Fontes: [Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [sessões anônimas](https://supabase.com/docs/guides/auth/auth-anonymous), [chaves](https://supabase.com/docs/guides/api/api-keys).

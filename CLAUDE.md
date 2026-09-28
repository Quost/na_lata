# Orientações do projeto Na Lata

Leia e siga [AGENTS.md](AGENTS.md), fonte compartilhada das práticas deste projeto.

Referências obrigatórias antes de implementar:

- [Contratos](docs/CONTRATOS.md): modelos, dependências e integração entre tasks.
- [Clientes](docs/CLIENTES.md): Widget → Repository → BackendClient/JsonApiClient.
- [Design system](docs/DESIGN_SYSTEM.md): tema, tokens, componentes e acessibilidade.
- [Git](docs/GIT.md): branch, commit, PR, revisão e merge.

Não chamar Supabase/HTTP diretamente em widgets nem criar cliente por funcionalidade. Usar injeção, erros padronizados, RLS e testes com fakes. Nunca usar chave administrativa no app. As funcionalidades pendentes pertencem aos alunos; implementar apenas o escopo solicitado.

Alunos podem criar novas tasks e devem testar suas funcionalidades, incluindo sucesso, erro e estado vazio. Antes de concluir, rodar análise e testes e registrar limitações reais. Para commits do professor no ambiente SENAI, usar professormatheusq <matheus.quost@edu.sc.senai.br>; alunos preservam sua autoria.

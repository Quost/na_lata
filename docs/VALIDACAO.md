# Verificação do template — 28/09/2026

- Flutter 3.38.5 / Dart 3.10.4.
- Análise estática: sem problemas.
- Três testes passaram: navegação catálogo/ficha, filtros no fake e identidade das avaliações simuladas.
- APK Android debug compilado com sucesso.
- Migração aplicada em PostgreSQL 17 temporário, com auth.users/auth.uid simulados para reproduzir o contrato Supabase.
- Teste SQL confirmou upsert, leitura compartilhada, bloqueio de alteração/exclusão de review alheia, isolamento de favoritos, rejeição de nota/comentário inválidos, rejeição de autor falso, denúncia única e bloqueio sem sessão.

Ainda requer configuração/validação no projeto Supabase real: autenticação anônima e execução da migração no Dashboard. O teste local não valida o serviço Auth hospedado.

Aparelho físico/câmera não foram testados: scanner é entrega T03 dos alunos. As funcionalidades pendentes são intencionais no template e estão nas issues.

## Atualização: base visual e clientes

Design system com galeria no app, componentes com testes de interação e layout a 320px/200%. Clientes Supabase e HTTP injetáveis com testes sem rede real de resultado, sessão ausente, permissão, conflito, validação, timeout e resposta inválida. O Supabase hospedado continua dependendo da configuração do projeto da aula.

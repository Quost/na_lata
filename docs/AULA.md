# Guia do professor — 18h às 22h

## Antes dos alunos chegarem

- Criar/aplicar Supabase conforme SUPABASE.md; deixar configuração distribuível.
- Conferir Flutter 3.38.5, Android SDK, emulador/aparelho e `flutter doctor`.
- Convidar alunos com permissão de escrita no repositório; conferir que Actions está habilitado.
- Validar clone + execução em uma máquina de aluno. Separar duas embalagens com barcode que existam no OFF.
- Configurar main com uma aprovação e check `verify`, se a organização/plano permitir. Evitar exigência de administrador para cada PR.
- Manter main executável. Só o professor coordena mudanças no núcleo e migrações.

## Limitação do GitHub desta organização

A configuração de proteção de main foi recusada pelo GitHub (HTTP 403: recurso indisponível no plano atual para este repositório privado). Revisão e check continuam obrigatórios pelo combinado da aula, mas não são impostos pelo servidor. Professor coordena os merges; alunos não fazem push direto em main. Não foi alterada a visibilidade do repositório.

## Cronograma

| Horário | Atividade |
|---|---|
| 18h–18h15 | Produto, critérios e template rodando |
| 18h15–18h35 | Demonstração curta de branch → commit → PR → revisão → merge |
| 18h35–19h25 | Primeira entrega individual |
| 19h25–19h45 | Primeiras revisões e merges, priorizando T01/T02/T08/T10 |
| 19h45–20h | Intervalo/checkpoint |
| 20h–20h45 | Integração e segunda rodada |
| 20h45–21h10 | Testes cruzados e correções |
| 21h10–21h20 | Congelamento progressivo; somente correções |
| 21h20–21h40 | Demonstração na máquina do professor |
| 21h40–22h | Retrospectiva e ponte para projeto final |

## Distribuição

Com 15 alunos, atribuir T01–T15, uma por pessoa. Todos têm um módulo Flutter, inclusive quem implementa repositório/helper: demonstram entrada/resultado/erro no próprio módulo. O primeiro bloco usa mocks; primeira integração real prioriza T01, T02, T08 e T10.

Com menos alunos, distribuir primeiro T01/T02/T04/T06/T07/T08/T09/T10. Depois scanner, busca, filtros, marca, ranking e moderação. T16–T24 são extensões para quem terminar, não promessa de 24 entregas em quatro horas.

Revisão em anel: aluno 1 revisa 2, 2 revisa 3, último revisa 1. Se alguém atrasar, redistribuir revisão sem tirar a responsabilidade de programar. Não reservar pessoas somente para docs/gestão/QA.

## Critério de concluído

Código Flutter, critérios de aceite demonstrados, revisão de colega, análise/testes passando e PR integrado. Lógica de parsing, notas e moderação deve ter testes específicos. Para UI simples, teste manual registrado com imagem é suficiente.

Acompanhar no GitHub: sem responsável = disponível, responsável = em andamento, PR ligado = em revisão, fechada pelo merge = concluída. Labels identificam prioridade e tipo; não é necessário configurar um Project para começar.

## Plano de contingência

- Git problemático: orientar recuperação e PR menor; nunca substituir o fluxo por envio de arquivo no WhatsApp.
- OFF indisponível: seguir com catálogo fictício, declarar que consulta externa não foi demonstrada.
- Supabase indisponível: desenvolver com fakes; persistência compartilhada não pode ser considerada concluída.
- Scanner sem aparelho: validar entrada manual; câmera fica pendente até teste físico.
- Às 21h20, demonstrar último main verde, sem fazer merge de código quebrado para “terminar”.

Fechar com: onde houve conflito, qual contrato ajudou, o que a revisão encontrou e o que fariam diferente no projeto final.

## Autonomia e qualidade

Os alunos são livres para criar novas tasks: proponham funcionalidades, melhorias e correções com critérios de aceite e combinem a prioridade com a turma. Todos devem programar e se preocupar com testes das funcionalidades: validar sucesso, erro e estado vazio; automatizar regras de negócio e interações relevantes; registrar evidências no PR.

Use o [design system](DESIGN_SYSTEM.md) para manter consistência visual.

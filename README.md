# Na Lata 🥫

**Comprou. Provou. Falou.** Um app Android de avaliações de alimentos, construído em equipe durante uma aula de Flutter.

Este repositório é o **ponto de partida**, não o aplicativo resolvido. A navegação, os contratos, os dados fictícios e a configuração de infraestrutura estão prontos. As funcionalidades pertencem às issues da turma.

## Começar em 5 minutos

Requer Flutter **3.38.5** (Dart 3.10.4), Android SDK e celular com depuração USB ou emulador.

```sh
git clone https://github.com/ADSSTech/na_lata.git
cd na_lata
flutter doctor
flutter pub get
flutter devices
flutter run
```

Sem configuração, abre em **DEMONSTRAÇÃO**: produtos e avaliações fictícios em memória. A câmera exige aparelho/câmera disponível. CRUD e demais entregas começam como módulos pendentes; não existe troca silenciosa para dados fictícios quando o Supabase falha.

## Sua primeira entrega

1. Escolha uma [issue](https://github.com/ADSSTech/na_lata/issues) livre e atribua a você.
2. Leia critérios de aceite, contrato e arquivos da tarefa.
3. Siga o [roteiro Git e PR](docs/GIT.md).
4. Implemente Flutter, demonstre o comportamento e peça revisão de um colega.
5. Revise e execute o PR de outra pessoa. **Todo mundo programa e revisa.**

## Guias

- [Roteiro da aula e preparação do professor](docs/AULA.md)
- [Configurar Supabase](docs/SUPABASE.md)
- [Contratos e pontos de integração](docs/CONTRATOS.md)
- [Backlog de 24 entregas](docs/BACKLOG.md)
- [Verificação final](docs/ACEITE.md)
- [Resultados de validação do template](docs/VALIDACAO.md)
- [Links das issues no GitHub](docs/ISSUES_GITHUB.md)

```sh
flutter analyze
flutter test
```

O catálogo externo vem do [Open Food Facts](https://world.openfoodfacts.org/). O banco local deste template é fictício e não foi extraído do serviço. Ao importar produtos reais, manter atribuição ao Open Food Facts (dados sob ODbL; imagens sob licença indicada pelo provedor).

**Corte de integração: 21h20.** Entregar um fluxo funcionando vale mais que muitas telas desconectadas.

## Autonomia e qualidade

Os alunos são livres para criar novas tasks: proponham funcionalidades, melhorias e correções com critérios de aceite e combinem a prioridade com a turma. Todos devem programar e se preocupar com testes das funcionalidades: validar sucesso, erro e estado vazio; automatizar regras de negócio e interações relevantes; registrar evidências no PR.

Use o [design system](docs/DESIGN_SYSTEM.md) para manter consistência visual.

## Acesso padronizado aos serviços

Todas as chamadas passam pelos clientes compartilhados. Leia [o guia de clientes](docs/CLIENTES.md) antes de implementar as consultas. Repositórios Supabase recebem BackendClient; chamadas usam client.request e a identidade vem de client.requireUserId.

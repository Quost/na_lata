# Design system · Na Lata

**Referência visual:** os componentes estão reunidos em `lib/design_system/gallery.dart`. **Importar:**

```dart
import 'package:na_lata/design_system/na_lata_ui.dart';
```

## Identidade

Direto, acolhedor e legível. Fundo creme, verde para ação principal, cartões brancos e notas em âmbar escuro. Ícones Material; fonte de sistema (sem download ou instalação). A tela deve ajudar a entender o produto e a avaliação.

| Token | Uso |
|---|---|
| NaColors.green / #176B4D | Ação principal |
| NaColors.cream / #F7F6F1 | Fundo |
| NaColors.ink / #202923 | Texto |
| NaColors.muted / #56625A | Texto secundário |
| NaColors.red / #B3261E | Erro, acompanhado de texto |
| NaColors.amber / #805600 | Estrelas/notas |
| NaSpace.xs/sm/md/lg/xl/xxl | 4 / 8 / 12 / 16 / 24 / 32 |
| NaRadius.card/control | 16 / 12 |
| NaSize.touch | Alvo de toque mínimo de 48 |
| NaSize.content | Largura máxima de conteúdo de 720 |

## Tipografia e composição

Use `Theme.of(context).textTheme`: headlineMedium para título de tela, titleLarge para seção, titleMedium para item, bodyLarge/bodyMedium para texto. Evite estilos locais que dupliquem tokens. Páginas usam NaSpace.page; blocos separados por xl, campos por lg. Não fixe altura para texto.

## Componentes disponíveis

- `NaContent(child:)`: limita largura e alinha conteúdo.
- `NaSection(title:, description:, child:)`: título, descrição e conteúdo.
- `NaButton(label:, onPressed:, loading:)`: ação principal; bloqueia toques enquanto carrega.
- `NaItemCard(title:, subtitle:, onTap:, leading:)`: item navegável.
- `NaRatingBadge(average:, count:)`: apresentação de nota já calculada; null/zero mostra “Sem avaliações”.
- `NaLoading`, `NaEmpty`, `NaError`: estados padronizados.
- `NaFilterSummary(items:, onRemove:, onClear:)`: contagem, chips removíveis e ação Limpar para os filtros ativos. Recebe `NaFilterItem(id:, dimension:, value:)` e devolve o `id` removido; não conhece a consulta. Cada remover tem tooltip e rótulo para leitor de tela, e os chips quebram linha em 320 px/200%.
- `TextFormField`, `FilterChip`, `OutlinedButton`, `SnackBar`: Material com tema compartilhado.

```dart
NaSection(
  title: 'Sua avaliação',
  child: NaButton(
    label: 'Publicar avaliação',
    loading: salvando,
    onPressed: salvar,
  ),
)
```

A galeria demonstra aparência e interações visuais mínimas. Não valida avaliações, não calcula médias, não consulta banco nem resolve as issues. O formulário de estrelas, validações e persistência continuam a cargo dos alunos.

## Acessibilidade e estados

Prever carregando, sucesso, vazio, erro e ação indisponível. Não comunicar erro só por cor. Ícones acionáveis têm tooltip; notas têm descrição para leitor de tela. Testar largura de 320 px e texto ampliado em 200%; usar Wrap/Expanded quando necessário. Mensagens dizem o que aconteceu e como tentar novamente.

## Novas tasks e testes

**Vocês são livres para criar novas tasks**, sugerir melhorias e novos componentes. Abrir issue com problema, comportamento esperado, critérios de aceite e como testar; combinar prioridade para caber na aula. Alteração compartilhada do design system deve ser coordenada antes de implementar.

Cada funcionalidade exige testes: caminho feliz e erro/vazio, teste automatizado de regras/parsing/cálculos, teste de widget para interação ou estado relevante e verificação manual em Android. Registrar no PR o que foi testado, modo usado e limitações. Não usar apenas screenshot ou “rodou aqui” como validação.

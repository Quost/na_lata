# Na Lata — próxima fase

O objetivo desta fase é transformar o protótipo em um produto útil para decidir **o que comprar e onde procurar**. A busca combina produto, marca, categoria, cidade/UF, nota e relatos recentes da comunidade. A localização é sempre o município onde o produto foi observado; ela não é inferida por GPS e não representa estoque garantido.

## Como escolher uma issue

As issues estão organizadas em quatro ciclos. Não há responsáveis pré definidos: cada aluno escolhe por afinidade, respeitando a prioridade e as dependências.

1. **P0 — Base confiável:** contratos de busca, autenticação recuperável, cidades/UF, RLS, dados e testes.
2. **P1 — Utilidade principal:** filtros combinados, marcas, preços, disponibilidade regional e custo por unidade.
3. **P2 — Comunidade saudável:** perfis, respostas, seguidores, feed, listas e moderação.
4. **P3 — Retenção e acabamento:** notificações, cache/offline, onboarding, acessibilidade e homologação.

Regra prática: escolha a issue de maior prioridade que esteja desbloqueada e que você consiga explicar em uma frase. Se houver duas opções equivalentes, escolha pela afinidade. Uma issue por branch e PR; o PR precisa ter testes de regra/parsing, interação ou integração conforme o escopo, além do roteiro manual.

Todas as issues foram criadas sem assignee para que a turma faça a distribuição. Ao assumir uma, escreva um comentário no issue e mova o card no projeto. Se uma dependência ainda não estiver pronta, ajude a testar ou escolha outra issue desbloqueada.

## Ciclo de entrega

Cada ciclo pode ser uma iteração do produto, não uma promessa de terminar em uma aula. Ao final de um ciclo, o app deve continuar instalável e o caminho principal deve continuar funcionando:

`descobrir produto → filtrar por região → abrir ficha → avaliar → consultar comunidade`

Banco e autenticação devem permanecer protegidos por RLS. Nenhuma chave administrativa, senha de banco ou token deve aparecer no Flutter, no PR ou no APK.

## Ideias de monetização para investigar depois

- **Afiliados e links de compra**, sempre identificados como publicidade e sem alterar a ordem orgânica dos resultados.
- **Alertas de preço e disponibilidade**, com plano pago opcional e limite gratuito transparente.
- **Painéis para marcas e varejistas**, usando dados agregados e anonimizados, sem vender avaliações individuais ou localização de pessoas.
- **Listas e comparadores premium**, com histórico de preço, exportação e alertas avançados.
- **Dados e API para parceiros**, somente com licença, atribuição do Open Food Facts quando houver dados derivados e respeito à ODbL.

Antes de monetizar, validar retenção, qualidade dos relatos, consentimento, LGPD e a separação entre recomendação editorial e anúncio.

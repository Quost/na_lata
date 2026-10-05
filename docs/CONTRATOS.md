# Contratos de integração

## Infraestrutura comum

`lib/core` define modelos, contratos e `AppScope`. `lib/feature_registry.dart` conecta as 24 entregas à navegação. O professor coordena alterações nesses arquivos, em `app.dart`, `main.dart`, dependências e SQL. Evite renomear contratos no meio da aula.

Cada módulo recebe `FeatureContext`: `scope` com repositórios e usuário atual, `product` opcional e callback `openProduct`. Módulos dependentes de produto devem mostrar orientação quando `product == null`; eles também podem ser abertos pela Oficina. Depois de gravar, chamar `scope.refresh()`. Não iniciar escrita ou HTTP dentro de `build`: usar eventos ou estado assíncrono.

`APP_MODE=demo` usa repositórios em memória; `APP_MODE=supabase` usa sessão anônima e banco real. `FeaturePending` identifica uma entrega ainda não implementada. O modo real inicia, mas exibirá pendências até T02/T08 serem entregues. O fake permite construir as interfaces antes disso.

## Modelos e banco

| Dart | SQL | Regra |
|---|---|---|
| Product.barcode | products.barcode | Texto, 8–14 dígitos no banco real; preservar zeros |
| Product.name | products.name | Nome obrigatório; fallback externo “Produto sem nome” |
| Product.brand | products.brand_key | Primeira marca da lista OFF, trim + minúsculas; null se ausente |
| Product.category | products.category | Primeiro categories_tags informado; null se ausente |
| Product.imageUrl | products.image_url | Pode ser null; UI trata erro de imagem |
| Review.userId | reviews.user_id | ID de auth, nunca apelido |
| Review.nickname | profiles.nickname | Obter por relação profiles, não duplicar em reviews |
| Review.rating | reviews.rating | Inteiro 1–5 |
| Review.comment | reviews.comment | Até 500 caracteres, opcional |

Categorias reais são os identificadores fornecidos pelo OFF; o protótipo não resolve taxonomia/tradução completa. Produtos fictícios usam categorias legíveis e códigos `demo-*`; não devem ser importados no banco real.

`reviews` tem unicidade `(barcode,user_id)`. Usar upsert com essas colunas; não enviar `id`, `created_at` ou `updated_at` no update. `profiles` nasce por trigger do auth. Favoritos e denúncias têm unicidade por usuário e alvo.

T08 implementa leitura/gravação e T17 depois implementa exclusão no mesmo repositório. T18/T19/T22/T23 editam métodos distintos em `supabase_community.dart`: sincronizar antes de começar e resolver conflitos preservando os métodos dos colegas. As tasks correspondentes também completam o fake para permitir demonstração sem rede.

## Busca e notas

Busca por nome consulta **catálogo importado**. Busca externa, somente por barcode, usa OFF v2. Catálogo e reviews são pequenos nesta aula; buscar listas e agregar no cliente é aceitável. O limite padrão de retorno do Supabase não é uma solução de paginação para produção.

T10 implementa `summarizeReviews`: média null quando não há notas; histograma de 1 a 5 e quantidade total. Marca agrega avaliações de todos os seus produtos, sem média das médias. Ranking desempata por quantidade e nome. T13/T14/T20/T21 dependem desse helper; usar fake em seus testes até o merge de T10.

T15 implementa `moderateComment`; T09 chama esse helper ao exibir comentário. Armazenar o texto original. Denúncia é encaminhada ao professor pelo Dashboard; não há remoção automática.

## Recursos locais e integração tardia

T24 exporta `Future<void> recordVisit(Product product, {required String userId})` usando SharedPreferences, com histórico separado por conta (`AppScope.userId`), limite de 50 e último acesso por produto. `app.dart` chama o helper nos dois callbacks de abertura de produto; nunca registrar visitas em build.

T03 e T04 consultam `scope.products.byBarcode`, depois `scope.openFoodFacts.lookup`, importam e chamam `openProduct`. Na demonstração, scanner usa códigos reais e rede; catálogo fictício não simula uma resposta OFF. Para desenvolver sem rede, injetar fake de OFF em teste.

## Serviço externo

OFF: `https://world.openfoodfacts.org/api/v2/product/{barcode}.json`. Pedir somente campos necessários; identificar o app com User-Agent, usar timeout e tratar 429 sem loop de retry. Produto com status=0 retorna null. JSON inválido, timeout e HTTP de erro devem ser diferenciados de “não encontrado”.

Referência: https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/

## Acesso padronizado aos serviços

Todas as chamadas passam pelos clientes compartilhados. Leia [o guia de clientes](CLIENTES.md) antes de implementar as consultas. Repositórios Supabase recebem BackendClient; chamadas usam client.request e a identidade vem de client.requireUserId.

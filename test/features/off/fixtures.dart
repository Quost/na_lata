/// Respostas reais de /api/v2/product/{barcode}.json (campos pedidos pela T01),
/// capturadas em 28/09/2026. Algumas foram reduzidas ou ajustadas para isolar
/// um cenário; o comentário de cada uma diz o que ela cobre.
library;

/// Produto completo: duas marcas, várias categorias e foto.
const offFound = '''
{"code":"7891000100103","product":{"brands":"Nestlé, Moça","categories_tags":["en:dairies","en:condensed-milks"],"code":"7891000100103","image_front_url":"https://images.openfoodfacts.org/images/products/789/100/010/0103/front_pt.34.400.jpg","product_name":"Leite Condensado Integral moça"},"status":1,"status_verbose":"product found"}
''';

/// OFF devolve o UPC de 12 dígitos normalizado para 13 no campo code.
const offNormalizedCode = '''
{"code":"0041196910759","product":{"brands":"Progresso","categories_tags":["en:canned-foods","en:meals"],"code":"0041196910759","image_front_url":"https://images.openfoodfacts.org/images/products/004/119/691/0759/front_en.25.400.jpg","product_name":"Beef & Vegetable Soup"},"status":1,"status_verbose":"product found"}
''';

/// Produto sem foto, sem nome, sem marca e sem categoria.
const offIncomplete = '''
{"code":"7890000000024","product":{"brands":"","categories_tags":[],"code":"7890000000024","product_name":"   "},"status":1,"status_verbose":"product found"}
''';

/// Produto inexistente (o OFF envia este corpo com HTTP 404).
const offNotFound = '''
{"code":"7890000000017","status":0,"status_verbose":"product not found"}
''';

/// status 1 sem o objeto product: estrutura inválida.
const offMissingProduct = '''
{"code":"7891000100103","status":1,"status_verbose":"product found"}
''';

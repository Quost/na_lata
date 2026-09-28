# Clientes compartilhados

Fluxo: **Widget → contrato de repositório → implementação → cliente compartilhado → serviço**.

`main.dart` cria um `BackendClient` e injeta a mesma instância nos três repositórios Supabase. A UI conhece apenas os contratos via AppScope. Não criar `SupabaseClient`, usar `Supabase.instance` ou chamar HTTP dentro de widgets.

## Supabase

O cliente padroniza timeout de 10 segundos, sessão atual e erros seguros, mantendo o query builder oficial dentro de um callback. Cada tarefa continua responsável pela consulta e pelo mapeamento do resultado em modelos.

```dart
// Dentro de um repositório, não dentro de build().
final rows = await client.request(
  (db) => db.from('products').select().eq('category', category),
);
// Mapear rows para List<Product> na implementação da tarefa.
```

Para gravações, obtenha `client.requireUserId`; nunca aceite user_id informado pelo formulário. A RLS do banco decide autorização, não o widget. `client.request` retorna o valor original da consulta. UPDATE/DELETE que afetam zero linhas podem não lançar erro: use `.select()` após a mutação e confira o retorno antes de mostrar sucesso.

O bootstrap desativa retry automático do PostgREST com `PostgrestClientOptions(retryEnabled: false)`. Ao injetar outro SupabaseClient em testes, mantenha essa opção. O wrapper não adiciona retry. Um timeout de escrita não cancela a operação remota: consulte o estado antes de reenviar. Use as restrições únicas e os contratos de upsert documentados. `AppFailure.kind` diferencia erro de rede, timeout, permissão, conflito e validação; `message` pode ser exibida. Erros de programação continuam visíveis nos testes e não são transformados em lista vazia.

## HTTP / Open Food Facts

`HttpOpenFoodFactsRepository` recebe `JsonApiClient`. A T01 usa `api.getObject(uri)` e implementa o parsing de Product. O cliente cuida de cabeçalhos, timeout, HTTP 429 e JSON inválido; não interpreta status de negócio (por exemplo OFF status=0). Construa URLs com `Uri` e parâmetros; não concatene entrada do usuário sem validação.

Não misturar credenciais Supabase em requisições externas. O cliente HTTP só envia Accept e User-Agent; não registra respostas, tokens ou comentários no console.

## Testes

Injete `http.MockClient` em `JsonApiClient` ou no construtor oficial de `SupabaseClient(httpClient: ...)` e envolva em BackendClient. Use fixtures sem rede real. Na UI injete repositório fake pelo AppScope. Ver exemplos em `test/clients_test.dart`.

Testar: retorno correto, conversão, timeout, permissão, conflito, resposta inválida e estado de erro da interface. Não usar banco real nos testes unitários/CI. O teste de integração real fica separado e deve registrar o ambiente usado.

## Liberdade com responsabilidade

A turma pode criar novas tasks. Se uma entrega exige ampliar o cliente ou contrato compartilhado, abrir issue e combinar com o professor para não quebrar trabalhos paralelos. Não implementar funcionalidades das outras issues como efeito colateral.

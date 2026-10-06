# Integração UX04 (#118)

## Situação das dependências em 05/10/2026

- #89 (CAT03): aberta; Product ainda não expõe quantidade/unidade.
- #99 (PRE03): aberta; não há PriceRepository/histórico de preços na main.
- #77 (GEO02): aberta; AppScope ainda não expõe região selecionada.
- Nenhum PR aberto dessas três entregas foi encontrado na consulta ao repositório.

Esta entrega mantém modelos/ponte dentro de compare. Não muda core, SQL,
navegação ou dependências. A aplicação usa PendingUnitPriceRepository até
a integração real: mostra a pendência, preservando as avaliações.
Não há dados de preço fictícios no modo real ou fallback silencioso.

## Conectar depois das dependências

Implementar UnitPriceRepository usando os repositórios injetados no AppScope
e passá-lo ao CompareFeature pelo registro da feature, com coordenação do professor.

- quantity: mapear os campos estruturados da CAT03 para PackageQuantity
  (decimal exato em texto e enum g/kg/ml/l); desconhecidos ficam null.
- window: obter cidade ID/UF e rótulo da GEO02, mais a janela definida pela PRE03.
  cityId null significa Todas as regiões; não confundir null com falha.
- observations: consultar **todas as páginas** da PRE03 na janela por produto,
  retornando centavos inteiros, observedAt, cidade e loja. Preservar erros.
  A camada local filtra novamente e escolhe o último observedAt; empate por ID.
- A janela é [from, until), e a UI explicita data/hora UTC e escopo.

Não usar o menor preço histórico como se fosse o último preço nem extrair
quantidade do nome do produto. Massa e volume permanecem incompatíveis.
Arredondamento monetário ocorre somente na exibição; o vencedor usa frações
exatas com BigInt.

## Roteiro manual (pendente)

Após conectar os repositórios, em demo com dados explícitos ou Supabase de teste:

1. Abrir Comparar, selecionar dois produtos equivalentes.
2. Conferir 500 g / 1000 centavos => R$ 20,00/kg, e 1 kg / 1500 => R$ 15,00/kg.
3. Conferir notas, fontes, lojas/datas diferentes e aviso de oferta não garantida.
4. Trocar região/janela; observações fora do filtro não participam.
5. Comparar g com ml, quantidade desconhecida e preço ausente: sem vencedor.
6. Simular erro de preços; notas continuam e Tentar novamente recupera.
7. Conferir 320 px, texto 200% e leitura com TalkBack.
8. Registrar aparelho, modo, resultado e evidência no PR.

A demonstração de custo nos testes usa FakeUnitPrices injetado.
A tela de produção não permite inserir preço/quantidade manualmente.

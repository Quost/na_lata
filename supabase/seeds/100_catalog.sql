-- QUA01 — catálogo de fixtures. Barcodes 200… são da faixa GS1 de uso interno
-- de loja: não colidem com produtos reais importados do Open Food Facts.
-- Upsert devolve cada produto ao valor conhecido mesmo se alguém o alterou.

insert into public.products (barcode, name, brand_key, category, image_url, created_at)
values
  ('2000000000011', 'Refrigerante Teste Cola 350ml', 'marca-teste', 'bebidas', null, '2026-01-01 12:00:00+00'),
  ('2000000000028', 'Suco Teste Uva 1L', 'marca-teste', 'bebidas', null, '2026-01-01 12:00:00+00'),
  ('2000000000035', 'Biscoito Teste Chocolate 140g', 'outra-marca', 'biscoitos', null, '2026-01-01 12:00:00+00'),
  ('2000000000042', 'Achocolatado Teste 400g', 'outra-marca', 'matinais', null, '2026-01-01 12:00:00+00'),
  -- Sem avaliações: estado vazio da ficha e livre para os testes de escrita.
  ('2000000000059', 'Água Teste sem Gás 500ml', 'marca-teste', 'bebidas', null, '2026-01-01 12:00:00+00')
on conflict (barcode) do update set
  name = excluded.name,
  brand_key = excluded.brand_key,
  category = excluded.category,
  image_url = excluded.image_url,
  created_at = excluded.created_at;

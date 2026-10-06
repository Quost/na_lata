-- QUA01 — listas (LIS01): A tem uma lista privada e uma pública.
-- B deve enxergar só a pública; nenhuma das duas aceita escrita de B.

insert into public.product_lists (id, owner_id, name, description, visibility, created_at, updated_at)
values
  ('f0000000-0000-4000-8000-0000000000a1', 'aaaaaaaa-0000-4000-8000-00000000000a', 'Compras do mês', null, 'private', '2026-01-07 12:00:00+00', '2026-01-07 12:00:00+00'),
  ('f0000000-0000-4000-8000-0000000000a2', 'aaaaaaaa-0000-4000-8000-00000000000a', 'Favoritas para festa', 'Lista pública de A.', 'public', '2026-01-08 12:00:00+00', '2026-01-08 12:00:00+00');

insert into public.list_items (list_id, barcode, created_at)
values
  ('f0000000-0000-4000-8000-0000000000a1', '2000000000042', '2026-01-07 12:00:00+00'),
  ('f0000000-0000-4000-8000-0000000000a2', '2000000000011', '2026-01-08 12:00:00+00'),
  ('f0000000-0000-4000-8000-0000000000a2', '2000000000028', '2026-01-08 12:01:00+00');

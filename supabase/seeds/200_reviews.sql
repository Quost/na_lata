-- QUA01 — avaliações das contas A/B (recriadas a cada seed via 000_accounts).
-- O trigger touch_review só age em UPDATE, então as datas abaixo são mantidas.

insert into public.reviews (id, barcode, user_id, rating, comment, created_at, updated_at)
values
  ('c0000000-0000-4000-8000-0000000000a1', '2000000000011', 'aaaaaaaa-0000-4000-8000-00000000000a', 5, 'Gelado fica ótimo.', '2026-01-02 12:00:00+00', '2026-01-02 12:00:00+00'),
  ('c0000000-0000-4000-8000-0000000000b1', '2000000000011', 'bbbbbbbb-0000-4000-8000-00000000000b', 3, 'Doce demais para mim.', '2026-01-03 12:00:00+00', '2026-01-03 12:00:00+00'),
  ('c0000000-0000-4000-8000-0000000000a2', '2000000000028', 'aaaaaaaa-0000-4000-8000-00000000000a', 4, '', '2026-01-04 12:00:00+00', '2026-01-04 12:00:00+00'),
  ('c0000000-0000-4000-8000-0000000000b2', '2000000000035', 'bbbbbbbb-0000-4000-8000-00000000000b', 2, 'Quebrou todo no pacote.', '2026-01-05 12:00:00+00', '2026-01-05 12:00:00+00');

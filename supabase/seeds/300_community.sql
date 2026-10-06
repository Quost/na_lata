-- QUA01 — favoritos, relatos por cidade e denúncia das contas A/B.

insert into public.favorites (user_id, barcode)
values
  ('aaaaaaaa-0000-4000-8000-00000000000a', '2000000000011'),
  ('bbbbbbbb-0000-4000-8000-00000000000b', '2000000000035');

insert into public.sightings (id, barcode, user_id, store, city, created_at)
values
  ('d0000000-0000-4000-8000-0000000000a1', '2000000000011', 'aaaaaaaa-0000-4000-8000-00000000000a', 'Mercado Central', 'Florianópolis', '2026-01-02 13:00:00+00'),
  ('d0000000-0000-4000-8000-0000000000a2', '2000000000028', 'aaaaaaaa-0000-4000-8000-00000000000a', 'Feira do Bairro', 'São José', '2026-01-04 13:00:00+00'),
  ('d0000000-0000-4000-8000-0000000000b1', '2000000000011', 'bbbbbbbb-0000-4000-8000-00000000000b', 'Atacado Norte', 'Joinville', '2026-01-03 13:00:00+00'),
  ('d0000000-0000-4000-8000-0000000000b2', '2000000000035', 'bbbbbbbb-0000-4000-8000-00000000000b', 'Mercado Vale', 'Blumenau', '2026-01-05 13:00:00+00');

-- B denunciou a avaliação de A: A não deve conseguir ler esta denúncia.
insert into public.reports (id, review_id, user_id, reason, status, created_at)
values
  ('e0000000-0000-4000-8000-0000000000b1', 'c0000000-0000-4000-8000-0000000000a1', 'bbbbbbbb-0000-4000-8000-00000000000b', 'outro', 'pending', '2026-01-06 12:00:00+00');

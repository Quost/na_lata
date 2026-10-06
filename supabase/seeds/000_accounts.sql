-- QUA01 — contas de teste A/B. SOMENTE Supabase local (supabase db reset).
-- Senha fixa e pública de propósito: nunca execute este arquivo no projeto da turma.
--
-- Idempotente: apaga as contas fixas antes de recriar. O cascade remove tudo o
-- que pertence a elas (profiles, reviews, favorites, reports, sightings, listas),
-- então os arquivos seguintes sempre partem do mesmo estado.
--
-- IDs fixos (ver supabase/seeds/README.md):
--   A = aaaaaaaa-0000-4000-8000-00000000000a  aluno.a@nalata.local
--   B = bbbbbbbb-0000-4000-8000-00000000000b  aluno.b@nalata.local

delete from auth.users
where id in (
  'aaaaaaaa-0000-4000-8000-00000000000a',
  'bbbbbbbb-0000-4000-8000-00000000000b'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated',
  u.email, extensions.crypt('nalata-local-123', extensions.gen_salt('bf')),
  '2026-01-01 12:00:00+00',
  '{"provider":"email","providers":["email"]}', '{}',
  '2026-01-01 12:00:00+00', '2026-01-01 12:00:00+00',
  '', '', '', ''
from (values
  ('aaaaaaaa-0000-4000-8000-00000000000a'::uuid, 'aluno.a@nalata.local'),
  ('bbbbbbbb-0000-4000-8000-00000000000b'::uuid, 'aluno.b@nalata.local')
) as u(id, email);

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at
)
select
  u.id, u.id, u.id::text, 'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  '2026-01-01 12:00:00+00', '2026-01-01 12:00:00+00', '2026-01-01 12:00:00+00'
from auth.users u
where u.id in (
  'aaaaaaaa-0000-4000-8000-00000000000a',
  'bbbbbbbb-0000-4000-8000-00000000000b'
);

-- O trigger create_classroom_profile já criou os perfis; só definimos o apelido.
update public.profiles set nickname = 'Aluno A'
where id = 'aaaaaaaa-0000-4000-8000-00000000000a';
update public.profiles set nickname = 'Aluno B'
where id = 'bbbbbbbb-0000-4000-8000-00000000000b';

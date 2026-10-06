-- PER01 — perfil público. Executar uma vez no SQL Editor, depois de 202609280001_classroom.sql.
-- Aditiva: não recria profiles nem o trigger create_classroom_profile; apelidos existentes ficam como estão.
begin;
-- Bio é opcional (null). Quando informada, tem 1–160 caracteres e não é só espaço.
alter table public.profiles
  add column bio text check (char_length(bio) <= 160 and char_length(btrim(bio)) >= 1);

-- Leitura e edição por coluna: o que não estiver listado aqui não é lido nem alterado pelo app.
-- Coluna futura (papel de moderador, preferência privada) nasce fechada até ganhar grant próprio.
revoke select, update on public.profiles from authenticated;
grant select(id, nickname, bio) on public.profiles to authenticated;
grant update(nickname, bio) on public.profiles to authenticated;
-- As policies profiles_read e profiles_own_update continuam valendo: todos leem, cada um edita só o seu.
commit;

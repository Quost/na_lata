-- PER01 — executar no SQL Editor como postgres, depois das migrações. Tudo é revertido ao final.
begin;
-- O trigger create_classroom_profile precisa continuar criando o perfil com apelido padrão e sem bio.
insert into auth.users (id) values
 ('a1a1a1a1-1111-4111-8111-111111111111'),
 ('b2b2b2b2-2222-4222-8222-222222222222');
-- Simula coluna privada futura (ex.: papel de moderador): não pode nascer legível nem editável.
alter table public.profiles add column role_probe text not null default 'user';
do $$
declare col text;
begin
 if (select count(*) from public.profiles where id in ('a1a1a1a1-1111-4111-8111-111111111111','b2b2b2b2-2222-4222-8222-222222222222') and nickname='Colega' and bio is null) <> 2 then raise exception 'Trigger não criou perfil padrão'; end if;
 if has_table_privilege('authenticated','public.profiles','SELECT') then raise exception 'Leitura da tabela inteira continua liberada'; end if;
 for col in select attname from pg_attribute where attrelid='public.profiles'::regclass and attnum > 0 and not attisdropped loop
  if has_column_privilege('authenticated','public.profiles',col,'SELECT') <> (col in ('id','nickname','bio')) then raise exception 'Leitura inesperada da coluna %', col; end if;
  if has_column_privilege('authenticated','public.profiles',col,'UPDATE') <> (col in ('nickname','bio')) then raise exception 'Edição inesperada da coluna %', col; end if;
 end loop;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
do $$
declare affected integer;
begin
 update public.profiles set nickname='Ana', bio='Gosto de café ☕' where id='a1a1a1a1-1111-4111-8111-111111111111';
 get diagnostics affected = row_count;
 if affected <> 1 then raise exception 'Dono não conseguiu editar o próprio perfil'; end if;
 update public.profiles set bio=repeat('é',160) where id='a1a1a1a1-1111-4111-8111-111111111111';
 update public.profiles set bio=null where id='a1a1a1a1-1111-4111-8111-111111111111';
 update public.profiles set bio='Gosto de café ☕' where id='a1a1a1a1-1111-4111-8111-111111111111';
 begin
  update public.profiles set bio=repeat('a',161) where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Aceitou bio com 161 caracteres';
 exception when check_violation then null; end;
 begin
  update public.profiles set bio='   ' where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Aceitou bio só com espaços';
 exception when check_violation then null; end;
 begin
  update public.profiles set nickname=' a ' where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Aceitou apelido com 1 caractere';
 exception when check_violation then null; end;
 begin
  update public.profiles set nickname=repeat('a',41) where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Aceitou apelido com 41 caracteres';
 exception when check_violation then null; end;
 begin
  update public.profiles set role_probe='moderator' where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Usuário alterou coluna privada';
 exception when insufficient_privilege then null; end;
 begin
  update public.profiles set id='b2b2b2b2-2222-4222-8222-222222222222' where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Usuário trocou o id do perfil';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.profiles(id, nickname) values (gen_random_uuid(), 'Fantasma');
  raise exception 'Usuário criou perfil avulso';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.profiles where id='a1a1a1a1-1111-4111-8111-111111111111';
  raise exception 'Usuário apagou perfil';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
do $$
declare affected integer;
begin
 if (select count(*) from public.profiles where id='a1a1a1a1-1111-4111-8111-111111111111' and nickname='Ana' and bio='Gosto de café ☕') <> 1 then raise exception 'Perfil público de A não está legível para B'; end if;
 update public.profiles set nickname='Invadido', bio='Invadida' where id='a1a1a1a1-1111-4111-8111-111111111111';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Alterou perfil alheio'; end if;
 begin
  perform role_probe from public.profiles;
  raise exception 'Leu coluna privada';
 exception when insufficient_privilege then null; end;
 begin
  perform * from public.profiles;
  raise exception 'select * expôs coluna privada';
 exception when insufficient_privilege then null; end;
 begin
  perform email from auth.users;
  raise exception 'Leu email de auth.users';
 exception when insufficient_privilege then null; end;
end $$;

set local role anon;
do $$ begin
 begin
  perform id, nickname, bio from public.profiles;
  raise exception 'Permitiu leitura de perfis sem sessão';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.profiles where id='a1a1a1a1-1111-4111-8111-111111111111' and nickname='Ana' and role_probe='user') <> 1 then raise exception 'Perfil de A foi alterado fora do esperado'; end if;
end $$;
rollback;

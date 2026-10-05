-- LIS01 — executar no SQL Editor como postgres, depois das migrações. Tudo é revertido ao final.
-- A e B são contas confirmadas; C é visitante anônimo.
begin;
insert into auth.users (id, email_confirmed_at, is_anonymous) values
 ('a1a1a1a1-1111-4111-8111-111111111111', now(), false),
 ('b2b2b2b2-2222-4222-8222-222222222222', now(), false),
 ('c3c3c3c3-3333-4333-8333-333333333333', null, true);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
insert into public.products(barcode,name) values ('00000000888888','Produto lista RLS'), ('00000000777777','Outro produto RLS');
insert into public.favorites values ('a1a1a1a1-1111-4111-8111-111111111111','00000000888888');
insert into public.product_lists(id,owner_id,name) values
 ('d4d4d4d4-4444-4444-8444-444444444444','a1a1a1a1-1111-4111-8111-111111111111','Privada de A');
insert into public.product_lists(id,owner_id,name,description,visibility) values
 ('e5e5e5e5-5555-4555-8555-555555555555','a1a1a1a1-1111-4111-8111-111111111111','Pública de A','Recomendações','public');
insert into public.list_items(list_id,barcode) values
 ('d4d4d4d4-4444-4444-8444-444444444444','00000000888888'),
 ('d4d4d4d4-4444-4444-8444-444444444444','00000000777777'),
 ('e5e5e5e5-5555-4555-8555-555555555555','00000000777777');
-- Mesmo contrato do app: upsert ignorando duplicata.
insert into public.list_items(list_id,barcode) values ('d4d4d4d4-4444-4444-8444-444444444444','00000000888888')
on conflict (list_id,barcode) do nothing;
do $$
declare affected integer;
begin
 if (select visibility from public.product_lists where id='d4d4d4d4-4444-4444-8444-444444444444') <> 'private' then raise exception 'Lista não nasceu privada'; end if;
 if (select count(*) from public.list_items where list_id='d4d4d4d4-4444-4444-8444-444444444444') <> 2 then raise exception 'Duplicou produto na lista'; end if;
 begin
  insert into public.list_items(list_id,barcode) values ('d4d4d4d4-4444-4444-8444-444444444444','00000000888888');
  raise exception 'Aceitou item duplicado';
 exception when unique_violation then null; end;
 begin
  insert into public.product_lists(owner_id,name) values ('a1a1a1a1-1111-4111-8111-111111111111','   ');
  raise exception 'Aceitou nome vazio';
 exception when check_violation then null; end;
 begin
  insert into public.product_lists(owner_id,name) values ('a1a1a1a1-1111-4111-8111-111111111111',repeat('a',61));
  raise exception 'Aceitou nome com 61 caracteres';
 exception when check_violation then null; end;
 begin
  insert into public.product_lists(owner_id,name,description) values ('a1a1a1a1-1111-4111-8111-111111111111','Ok',repeat('a',201));
  raise exception 'Aceitou descrição com 201 caracteres';
 exception when check_violation then null; end;
 begin
  insert into public.product_lists(owner_id,name,visibility) values ('a1a1a1a1-1111-4111-8111-111111111111','Ok','secret');
  raise exception 'Aceitou visibilidade inválida';
 exception when check_violation then null; end;
 update public.product_lists set name='Privada renomeada', description='Só minha' where id='d4d4d4d4-4444-4444-8444-444444444444';
 get diagnostics affected = row_count;
 if affected <> 1 then raise exception 'Dono não conseguiu editar'; end if;
 begin
  update public.product_lists set owner_id='b2b2b2b2-2222-4222-8222-222222222222' where id='d4d4d4d4-4444-4444-8444-444444444444';
  raise exception 'Permitiu trocar dono';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
do $$
declare affected integer;
begin
 if exists(select 1 from public.product_lists where id='d4d4d4d4-4444-4444-8444-444444444444') then raise exception 'Vazou lista privada'; end if;
 if exists(select 1 from public.list_items where list_id='d4d4d4d4-4444-4444-8444-444444444444') then raise exception 'Vazou item de lista privada'; end if;
 if (select count(*) from public.list_items i join public.product_lists l on l.id=i.list_id where l.owner_id='a1a1a1a1-1111-4111-8111-111111111111') <> 1 then raise exception 'Join expôs itens privados'; end if;
 if (select count(*) from public.list_items i join public.products p on p.barcode=i.barcode where p.barcode='00000000888888') <> 0 then raise exception 'Join por produto expôs lista privada'; end if;
 if (select count(*) from public.product_lists where id='e5e5e5e5-5555-4555-8555-555555555555') <> 1 then raise exception 'Lista pública não está legível'; end if;
 if (select count(*) from public.list_items where list_id='e5e5e5e5-5555-4555-8555-555555555555') <> 1 then raise exception 'Itens públicos não estão legíveis'; end if;
 if exists(select 1 from public.favorites) then raise exception 'Vazou favorito alheio'; end if;
 update public.product_lists set name='Invadida' where id in ('d4d4d4d4-4444-4444-8444-444444444444','e5e5e5e5-5555-4555-8555-555555555555');
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Alterou lista alheia'; end if;
 delete from public.product_lists where id in ('d4d4d4d4-4444-4444-8444-444444444444','e5e5e5e5-5555-4555-8555-555555555555');
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Excluiu lista alheia'; end if;
 delete from public.list_items where list_id='e5e5e5e5-5555-4555-8555-555555555555';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Excluiu item de lista alheia'; end if;
 begin
  insert into public.list_items(list_id,barcode) values ('e5e5e5e5-5555-4555-8555-555555555555','00000000888888');
  raise exception 'Adicionou item em lista pública alheia';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.product_lists(owner_id,name) values ('a1a1a1a1-1111-4111-8111-111111111111','Em nome de A');
  raise exception 'Criou lista para outro dono';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.product_lists(owner_id,name) values ('b2b2b2b2-2222-4222-8222-222222222222','Lista de B');

select set_config('request.jwt.claim.sub', 'c3c3c3c3-3333-4333-8333-333333333333', true);
do $$ begin
 if (select count(*) from public.product_lists where owner_id='a1a1a1a1-1111-4111-8111-111111111111') <> 1 then raise exception 'Visitante deveria ler só a lista pública'; end if;
 begin
  insert into public.product_lists(owner_id,name) values ('c3c3c3c3-3333-4333-8333-333333333333','Lista do visitante');
  raise exception 'Visitante anônimo criou lista';
 exception when insufficient_privilege then null; end;
 -- Favoritos legados continuam abertos ao visitante.
 insert into public.favorites values ('c3c3c3c3-3333-4333-8333-333333333333','00000000888888');
end $$;

select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
delete from public.product_lists where id='d4d4d4d4-4444-4444-8444-444444444444';
set local role anon;
do $$ begin
 begin
  perform * from public.product_lists;
  raise exception 'Permitiu leitura de listas sem sessão';
 exception when insufficient_privilege then null; end;
 begin
  perform * from public.list_items;
  raise exception 'Permitiu leitura de itens sem sessão';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.list_items where list_id='d4d4d4d4-4444-4444-8444-444444444444') then raise exception 'Exclusão da lista não limpou itens'; end if;
 if (select count(*) from public.favorites where barcode='00000000888888') <> 2 then raise exception 'Favoritos foram afetados pelas listas'; end if;
 if (select count(*) from public.product_lists where owner_id in ('a1a1a1a1-1111-4111-8111-111111111111','b2b2b2b2-2222-4222-8222-222222222222','c3c3c3c3-3333-4333-8333-333333333333')) <> 2 then raise exception 'Listas foram criadas fora do esperado'; end if;
end $$;
rollback;

-- Executar no SQL Editor como postgres. Tudo é revertido ao final.
begin;
insert into auth.users (id) values
 ('a1a1a1a1-1111-4111-8111-111111111111'),
 ('b2b2b2b2-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
insert into public.products(barcode,name) values ('00000000999999','Produto teste RLS');
insert into public.reviews(id,barcode,user_id,rating,comment) values
 ('c3c3c3c3-3333-4333-8333-333333333333','00000000999999','a1a1a1a1-1111-4111-8111-111111111111',4,'Original');
insert into public.reviews(barcode,user_id,rating,comment) values
 ('00000000999999','a1a1a1a1-1111-4111-8111-111111111111',5,'Editada')
on conflict (barcode,user_id) do update set barcode=excluded.barcode,user_id=excluded.user_id,rating=excluded.rating,comment=excluded.comment;
insert into public.favorites values ('a1a1a1a1-1111-4111-8111-111111111111','00000000999999');
select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
do $$
declare affected integer;
begin
 if (select count(*) from public.reviews where id='c3c3c3c3-3333-4333-8333-333333333333' and rating=5) <> 1 then raise exception 'Leitura compartilhada/upsert falhou'; end if;
 update public.reviews set rating=1 where id='c3c3c3c3-3333-4333-8333-333333333333';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Alterou review alheia'; end if;
 delete from public.reviews where id='c3c3c3c3-3333-4333-8333-333333333333';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Excluiu review alheia'; end if;
 if exists(select 1 from public.favorites) then raise exception 'Vazou favorito alheio'; end if;
 begin
  insert into public.reviews(barcode,user_id,rating) values ('00000000999999','b2b2b2b2-2222-4222-8222-222222222222',6);
  raise exception 'Aceitou nota inválida';
 exception when check_violation then null; end;
 begin
  insert into public.reviews(barcode,user_id,rating,comment) values ('00000000999999','b2b2b2b2-2222-4222-8222-222222222222',3,repeat('a',501));
  raise exception 'Aceitou comentário longo';
 exception when check_violation then null; end;
 begin
  insert into public.reviews(barcode,user_id,rating) values ('00000000999999','a1a1a1a1-1111-4111-8111-111111111111',3);
  raise exception 'Aceitou outro autor';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.reports(review_id,user_id,reason) values ('c3c3c3c3-3333-4333-8333-333333333333','b2b2b2b2-2222-4222-8222-222222222222','outro');
do $$ begin
 begin
  insert into public.reports(review_id,user_id,reason) values ('c3c3c3c3-3333-4333-8333-333333333333','b2b2b2b2-2222-4222-8222-222222222222','spam');
  raise exception 'Aceitou denúncia duplicada';
 exception when unique_violation then null; end;
end $$;
set local role anon;
do $$ begin
 begin
  perform * from public.reviews;
  raise exception 'Permitiu leitura sem sessão';
 exception when insufficient_privilege then null; end;
end $$;
rollback;

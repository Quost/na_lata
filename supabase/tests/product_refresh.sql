-- CAT02 — executar no SQL Editor como postgres, depois das migrações. Tudo é revertido ao final.
begin;
insert into auth.users (id) values
 ('a1a1a1a1-1111-4111-8111-111111111111'),
 ('b2b2b2b2-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
insert into public.products(barcode,name,brand_key,category) values ('00000000660001','Nome antigo','marca','categoria antiga');
insert into public.reviews(id,barcode,user_id,rating,comment) values
 ('c3c3c3c3-3333-4333-8333-333333333333','00000000660001','a1a1a1a1-1111-4111-8111-111111111111',4,'Continua aqui');
insert into public.favorites values ('a1a1a1a1-1111-4111-8111-111111111111','00000000660001');
insert into public.sightings(barcode,user_id,store,city) values ('00000000660001','a1a1a1a1-1111-4111-8111-111111111111','Mercado','Joinville');
do $$
declare r record;
begin
 -- A única escrita em products é a função: UPDATE direto continua negado.
 begin
  update public.products set name='Invadido' where barcode='00000000660001';
  raise exception 'Permitiu UPDATE direto em products';
 exception when insufficient_privilege then null; end;
 begin
  perform * from public.product_refreshes;
  raise exception 'Leu o controle de frequência';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.product_refreshes(barcode, refreshed_at) values ('00000000660001', now() - interval '1 day');
  raise exception 'Gravou no controle de frequência';
 exception when insufficient_privilege then null; end;

 select * into r from public.refresh_product('00000000660001','  Nome antigo ','MARCA','categoria antiga',null);
 if r.status <> 'unchanged' then raise exception 'Sem mudança deveria ser unchanged, veio %', r.status; end if;
 if (select source from public.products where barcode='00000000660001') is not null then raise exception 'unchanged gravou na ficha'; end if;

 select * into r from public.refresh_product('00000000669999','Qualquer');
 if r.status <> 'not_found' then raise exception 'Produto inexistente deveria ser not_found, veio %', r.status; end if;
 if exists(select 1 from public.products where barcode='00000000669999') then raise exception 'Função criou produto'; end if;

 begin
  perform public.refresh_product('00000000660001','   ');
  raise exception 'Aceitou nome vazio';
 exception when check_violation then null; end;
 begin
  perform public.refresh_product('00000000660001',repeat('a',301));
  raise exception 'Aceitou nome com 301 caracteres';
 exception when check_violation then null; end;
 begin
  perform public.refresh_product('00000000660001','Nome novo',null,null,'https://example.com/foto.jpg');
  raise exception 'Aceitou foto fora do domínio da fonte';
 exception when check_violation then null; end;
 begin
  perform public.refresh_product('00000000660001','Nome novo',null,null,'http://images.openfoodfacts.org/foto.jpg');
  raise exception 'Aceitou foto sem HTTPS';
 exception when check_violation then null; end;
 if (select name from public.products where barcode='00000000660001') <> 'Nome antigo' then raise exception 'Tentativa inválida alterou a ficha'; end if;

 select * into r from public.refresh_product('00000000660001',' Nome novo ','Marca Nova','categoria nova','https://images.openfoodfacts.org/images/products/000/front.jpg');
 if r.status <> 'updated' then raise exception 'Mudança válida deveria ser updated, veio %', r.status; end if;
 if (select count(*) from public.products where barcode='00000000660001'
      and name='Nome novo' and brand_key='marca nova' and category='categoria nova'
      and image_url='https://images.openfoodfacts.org/images/products/000/front.jpg'
      and source='open_food_facts' and source_url='https://world.openfoodfacts.org/product/00000000660001'
      and source_fetched_at is not null) <> 1 then raise exception 'Ficha não ficou como esperado'; end if;
 -- Vínculos da comunidade continuam no mesmo produto.
 if (select count(*) from public.reviews where barcode='00000000660001' and rating=4 and comment='Continua aqui') <> 1 then raise exception 'Avaliação foi afetada'; end if;
 if (select count(*) from public.favorites where barcode='00000000660001') <> 1 then raise exception 'Favorito foi afetado'; end if;
 if (select count(*) from public.sightings where barcode='00000000660001' and city='Joinville') <> 1 then raise exception 'Relato foi afetado'; end if;
end $$;

-- Outro usuário, logo em seguida: o limite é por produto, não por pessoa.
select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
do $$
declare r record;
begin
 select * into r from public.refresh_product('00000000660001','Outro nome');
 if r.status <> 'rate_limited' then raise exception 'Segunda mudança deveria ser rate_limited, veio %', r.status; end if;
 if r.retry_after_seconds not between 1 and 3600 then raise exception 'Espera fora do intervalo: %', r.retry_after_seconds; end if;
 if (select name from public.products where barcode='00000000660001') <> 'Nome novo' then raise exception 'Limite não preservou a ficha'; end if;
 -- Repetir os mesmos dados já gravados não é erro nem nova gravação.
 select * into r from public.refresh_product('00000000660001','Nome novo','marca nova','categoria nova','https://images.openfoodfacts.org/images/products/000/front.jpg');
 if r.status <> 'unchanged' then raise exception 'Repetição deveria ser unchanged, veio %', r.status; end if;
end $$;

-- Passada uma hora, a próxima mudança é aceita.
reset role;
update public.product_refreshes set refreshed_at = now() - interval '61 minutes' where barcode='00000000660001';
set local role authenticated;
do $$
declare r record;
begin
 select * into r from public.refresh_product('00000000660001','Outro nome','marca nova','categoria nova','https://images.openfoodfacts.org/images/products/000/front.jpg');
 if r.status <> 'updated' then raise exception 'Após uma hora deveria ser updated, veio %', r.status; end if;
end $$;

set local role anon;
do $$ begin
 begin
  perform public.refresh_product('00000000660001','Sem sessão');
  raise exception 'Permitiu atualizar sem sessão';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.product_refreshes where barcode='00000000660001' and refreshed_by='b2b2b2b2-2222-4222-8222-222222222222') <> 1 then raise exception 'Controle de frequência não registrou a última atualização'; end if;
 if (select name from public.products where barcode='00000000660001') <> 'Outro nome' then raise exception 'Ficha final inesperada'; end if;
end $$;
rollback;

-- Executar no SQL Editor como postgres, após a migração de marcas.
-- Tudo é revertido ao final. Marcas com prefixo zzteste isolam os dados reais.
begin;
insert into auth.users (id) values ('d4d4d4d4-4444-4444-8444-444444444444');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4d4d4d4-4444-4444-8444-444444444444', true);
insert into public.products(barcode, name, brand_key) values
 ('00000000990001', 'Sem marca', null),
 ('00000000990002', 'Marca vazia', ''),
 ('00000000990003', 'Marca em branco', '   '),
 ('00000000990004', 'Acento', 'zzteste nestlé'),
 ('00000000990005', 'Acento com espaços', '  zzteste nestlé '),
 ('00000000990006', 'Sem acento', 'zzteste nestle'),
 ('00000000990007', 'Caixa alta', 'ZZTESTE Nestlé');
do $$
declare page1 text[]; page2 text[];
begin
 if exists(select 1 from public.search_brands('', null, 101) where brand is null or brand = '') then
  raise exception 'Marca nula/vazia virou registro';
 end if;
 -- Caixa e acentos não importam na pesquisa; brand_key diferentes não são fundidos.
 if (select array_agg(brand order by brand collate "C") from public.search_brands('ZZTESTE NESTLE', null, 101))
    <> array['ZZTESTE Nestlé', 'zzteste nestle', 'zzteste nestlé'] then
  raise exception 'Busca por caixa/acento falhou';
 end if;
 -- Espaços nas bordas agrupam com a mesma marca e cada produto conta uma vez.
 if (select product_count from public.search_brands('nestlé', null, 101) where brand = 'zzteste nestlé') <> 2 then
  raise exception 'Contagem de produtos errada';
 end if;
 -- Duas páginas sem repetir nem pular marcas.
 select array_agg(brand) into page1 from public.search_brands('zzteste', null, 2);
 select array_agg(brand) into page2 from public.search_brands('zzteste', page1[2], 2);
 if page1 <> array['ZZTESTE Nestlé', 'zzteste nestle'] or page2 <> array['zzteste nestlé'] then
  raise exception 'Paginação falhou: % / %', page1, page2;
 end if;
 begin
  perform * from public.search_brands('', null, 0);
  raise exception 'Aceitou página vazia';
 exception when invalid_parameter_value then null; end;
end $$;
set local role anon;
do $$ begin
 begin
  perform * from public.search_brands();
  raise exception 'Permitiu busca sem sessão';
 exception when insufficient_privilege then null; end;
end $$;
rollback;

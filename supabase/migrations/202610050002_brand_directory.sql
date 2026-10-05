-- Diretório de marcas (MAR01). Executar após 202609280001_classroom.sql.
-- A identidade continua sendo products.brand_key (sem espaços nas bordas);
-- caixa e acentos só são ignorados na pesquisa. Nenhuma FK é alterada.
begin;

-- Chave de pesquisa: sem bordas, espaços únicos, sem acentos e minúsculas.
create function public.brand_search_key(value text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select lower(translate(
    regexp_replace(btrim(value), '\s+', ' ', 'g'),
    'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñ',
    'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'
  ))
$$;

-- Página de marcas ordenada por brand_key; p_after é a última marca da
-- página anterior. Marca nula/vazia não aparece e cada produto conta uma vez.
create function public.search_brands(
  p_query text default '',
  p_after text default null,
  p_limit integer default 20
) returns table (brand text, product_count bigint)
language plpgsql stable security invoker set search_path = '' as $$
begin
  -- 101 = página máxima de 100 + 1 linha para saber se há próxima página.
  if p_limit is null or p_limit < 1 or p_limit > 101 then
    raise exception 'Tamanho de página inválido.' using errcode = '22023';
  end if;
  return query
  select btrim(p.brand_key), count(distinct p.barcode)
  from public.products p
  where btrim(p.brand_key) <> ''
    and strpos(
      public.brand_search_key(p.brand_key),
      public.brand_search_key(coalesce(p_query, ''))
    ) > 0
    and (p_after is null or btrim(p.brand_key) collate "C" > p_after collate "C")
  group by btrim(p.brand_key)
  order by btrim(p.brand_key) collate "C"
  limit p_limit;
end;
$$;

revoke all on function public.brand_search_key(text) from public, anon;
revoke all on function public.search_brands(text, text, integer) from public, anon;
grant execute on function public.brand_search_key(text) to authenticated;
grant execute on function public.search_brands(text, text, integer) to authenticated;
commit;

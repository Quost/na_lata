-- CAT02 — atualizar ficha pela fonte externa. Executar uma vez no SQL Editor,
-- depois de 202609280001_classroom.sql e 202610050001_product_source.sql.
-- products continua sem UPDATE para o app: a única escrita é a função abaixo.
begin;

-- Última atualização de cada produto; base do limite de frequência.
-- Sem grants: só a função (security definer) lê e grava.
create table public.product_refreshes (
  barcode text primary key references public.products(barcode) on delete cascade,
  refreshed_at timestamptz not null default now(),
  refreshed_by uuid references public.profiles(id) on delete set null
);
alter table public.product_refreshes enable row level security;
revoke all on public.product_refreshes from anon, authenticated;

-- Grava só nome, marca, categoria e foto, e registra a fonte com a hora do
-- servidor. Código de barras, avaliações, favoritos e relatos não são tocados.
-- status: updated | unchanged | rate_limited | not_found.
create function public.refresh_product(
  p_barcode text,
  p_name text,
  p_brand_key text default null,
  p_category text default null,
  p_image_url text default null
) returns table (status text, retry_after_seconds integer)
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_name text := btrim(coalesce(p_name, ''));
  v_brand text := nullif(lower(btrim(coalesce(p_brand_key, ''))), '');
  v_category text := nullif(btrim(coalesce(p_category, '')), '');
  v_image text := nullif(btrim(coalesce(p_image_url, '')), '');
  v_current public.products%rowtype;
  v_last timestamptz;
  v_wait constant interval := interval '1 hour';
begin
  if v_user is null then
    raise exception 'Sessão obrigatória.' using errcode = '42501';
  end if;
  select * into v_current from public.products p where p.barcode = p_barcode for update;
  if not found then
    return query select 'not_found'::text, 0;
    return;
  end if;
  -- Foto nova precisa vir do domínio da fonte; a foto já gravada pode ser mantida.
  if char_length(v_name) not between 1 and 300
     or char_length(v_brand) > 200
     or char_length(v_category) > 200
     or (v_image is distinct from v_current.image_url
         and (char_length(v_image) > 2000
              or v_image !~* '^https://([a-z0-9-]+\.)*openfoodfacts\.org/[^[:space:]]*$')) then
    raise exception 'Dados de catálogo inválidos.' using errcode = '23514';
  end if;
  if v_current.name = v_name
     and v_current.brand_key is not distinct from v_brand
     and v_current.category is not distinct from v_category
     and v_current.image_url is not distinct from v_image then
    return query select 'unchanged'::text, 0;
    return;
  end if;
  select r.refreshed_at into v_last from public.product_refreshes r where r.barcode = p_barcode;
  if v_last is not null and v_last > now() - v_wait then
    return query select 'rate_limited'::text,
      ceil(extract(epoch from (v_last + v_wait - now())))::integer;
    return;
  end if;
  update public.products p set
    name = v_name,
    brand_key = v_brand,
    category = v_category,
    image_url = v_image,
    source = 'open_food_facts',
    source_url = 'https://world.openfoodfacts.org/product/' || p_barcode,
    source_fetched_at = now()
  where p.barcode = p_barcode;
  insert into public.product_refreshes as r (barcode, refreshed_by) values (p_barcode, v_user)
  on conflict (barcode) do update set refreshed_at = now(), refreshed_by = excluded.refreshed_by;
  return query select 'updated'::text, 0;
end;
$$;

revoke all on function public.refresh_product(text, text, text, text, text) from public, anon;
grant execute on function public.refresh_product(text, text, text, text, text) to authenticated;
commit;

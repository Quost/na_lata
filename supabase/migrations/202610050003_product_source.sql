-- Origem dos dados do produto. Aditiva: produtos existentes ficam com NULL
-- (origem não informada); não há preenchimento retroativo de fonte ou data.
alter table public.products
  add column if not exists source text,
  add column if not exists source_url text,
  add column if not exists source_fetched_at timestamptz;

alter table public.products
  add constraint products_source_check
    check (source is null or source in ('open_food_facts')),
  add constraint products_source_url_check
    check (
      source_url is null
      or source_url ~* '^https://([a-z0-9-]+\.)*openfoodfacts\.org(/|$)'
    );

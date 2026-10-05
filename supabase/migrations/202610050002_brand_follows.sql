begin;

create table public.brands (
  brand_key text primary key
    check (char_length(btrim(brand_key)) between 1 and 120)
);

insert into public.brands (brand_key)
select distinct lower(btrim(brand_key))
from public.products
where brand_key is not null and char_length(btrim(brand_key)) between 1 and 120
on conflict do nothing;

create function public.register_product_brand() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.brand_key is not null
    and char_length(btrim(new.brand_key)) between 1 and 120 then
    insert into public.brands (brand_key)
    values (lower(btrim(new.brand_key)))
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger product_brand_catalog_updated
after insert or update of brand_key on public.products
for each row execute function public.register_product_brand();

create table public.brand_follows (
  user_id uuid not null references public.profiles(id) on delete cascade,
  brand_key text not null references public.brands(brand_key) on delete cascade,
  created_at timestamptz not null default now(),
  constraint brand_follows_user_brand_unique unique (user_id, brand_key)
);

create function public.is_active_confirmed_account() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from auth.users as account
    where account.id = (select auth.uid())
      and account.email_confirmed_at is not null
      and account.banned_until is null
      and account.deleted_at is null
  );
$$;

alter table public.brands enable row level security;
alter table public.brand_follows enable row level security;

revoke all on public.brands, public.brand_follows from anon, authenticated;
grant select on public.brands to authenticated;
grant select, insert, delete on public.brand_follows to authenticated;

create policy brands_read on public.brands
for select to authenticated using (true);

create policy brand_follows_own_read on public.brand_follows
for select to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_active_confirmed_account())
);

create policy brand_follows_own_insert on public.brand_follows
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_active_confirmed_account())
);

create policy brand_follows_own_delete on public.brand_follows
for delete to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_active_confirmed_account())
);

revoke all on function public.register_product_brand() from public, anon, authenticated;
revoke all on function public.is_active_confirmed_account() from public, anon, authenticated;
grant execute on function public.is_active_confirmed_account() to authenticated;

commit;

-- Execute uma vez no SQL Editor de um projeto Supabase exclusivo da aula.
begin;
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null default 'Colega' check (char_length(btrim(nickname)) between 2 and 40)
);
create table public.products (
  barcode text primary key check (barcode ~ '^[0-9]{8,14}$'),
  name text not null check (char_length(btrim(name)) between 1 and 300),
  brand_key text,
  category text,
  image_url text,
  created_at timestamptz not null default now()
);
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  barcode text not null references public.products(barcode),
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (barcode, user_id)
);
create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  barcode text not null references public.products(barcode),
  primary key (user_id, barcode)
);
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('ofensa', 'spam', 'outro')),
  status text not null default 'pending' check (status in ('pending', 'reviewed')),
  created_at timestamptz not null default now(),
  unique (review_id, user_id)
);
create table public.sightings (
  id uuid primary key default gen_random_uuid(),
  barcode text not null references public.products(barcode),
  user_id uuid not null references public.profiles(id) on delete cascade,
  store text not null check (char_length(btrim(store)) between 1 and 100),
  city text not null check (char_length(btrim(city)) between 1 and 100),
  created_at timestamptz not null default now()
);
create index reviews_user_idx on public.reviews(user_id);
create index sightings_barcode_idx on public.sightings(barcode);
create index products_brand_category_idx on public.products(brand_key, category);

create function public.create_classroom_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id) values (new.id);
  return new;
end;
$$;
create trigger classroom_profile_created after insert on auth.users
for each row execute function public.create_classroom_profile();
-- Também cobre usuários criados antes desta migração.
insert into public.profiles(id) select id from auth.users on conflict do nothing;

create function public.touch_review() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.created_at := old.created_at;
  new.updated_at := now();
  return new;
end;
$$;
create trigger review_updated before update on public.reviews
for each row execute function public.touch_review();

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;
alter table public.reports enable row level security;
alter table public.sightings enable row level security;
revoke all on public.profiles, public.products, public.reviews, public.favorites, public.reports, public.sightings from anon, authenticated;
grant select on public.profiles, public.products, public.reviews, public.sightings to authenticated;
grant update(nickname) on public.profiles to authenticated;
grant insert on public.products to authenticated;
grant insert, delete on public.reviews to authenticated;
grant update(rating, comment) on public.reviews to authenticated;
-- Upsert envia as colunas de conflito também; RLS impede trocar autor.
grant update(barcode, user_id) on public.reviews to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert on public.reports to authenticated;
grant insert on public.sightings to authenticated;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_own_update on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy products_read on public.products for select to authenticated using (true);
create policy products_import on public.products for insert to authenticated with check ((select auth.uid()) is not null);
create policy reviews_read on public.reviews for select to authenticated using (true);
create policy reviews_own_insert on public.reviews for insert to authenticated with check (user_id = (select auth.uid()));
create policy reviews_own_update on public.reviews for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy reviews_own_delete on public.reviews for delete to authenticated using (user_id = (select auth.uid()));
create policy favorites_own_read on public.favorites for select to authenticated using (user_id = (select auth.uid()));
create policy favorites_own_insert on public.favorites for insert to authenticated with check (user_id = (select auth.uid()));
create policy favorites_own_delete on public.favorites for delete to authenticated using (user_id = (select auth.uid()));
create policy reports_own_read on public.reports for select to authenticated using (user_id = (select auth.uid()));
create policy reports_own_insert on public.reports for insert to authenticated with check (user_id = (select auth.uid()) and status = 'pending');
create policy sightings_read on public.sightings for select to authenticated using (true);
create policy sightings_own_insert on public.sightings for insert to authenticated with check (user_id = (select auth.uid()));
revoke all on function public.create_classroom_profile() from public, anon, authenticated;
revoke all on function public.touch_review() from public, anon, authenticated;
commit;

-- LIS01 — listas de produtos. Executar uma vez no SQL Editor, depois de 202609280001_classroom.sql.
-- Não altera nem migra a tabela favorites: favoritos continuam independentes das listas.
begin;
create table public.product_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) <= 60 and char_length(btrim(name)) >= 1),
  description text check (char_length(description) <= 200),
  visibility text not null default 'private' check (visibility in ('private', 'public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.list_items (
  list_id uuid not null references public.product_lists(id) on delete cascade,
  barcode text not null references public.products(barcode),
  created_at timestamptz not null default now(),
  primary key (list_id, barcode)
);
create index product_lists_owner_idx on public.product_lists(owner_id);
create index list_items_barcode_idx on public.list_items(barcode);

-- Conta confirmada = usuário não anônimo com email ou telefone confirmado.
-- security definer porque authenticated não lê auth.users; só devolve booleano do próprio usuário.
create function public.is_confirmed_account() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u
    where u.id = (select auth.uid())
      and not coalesce(u.is_anonymous, false)
      and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null)
  );
$$;

create function public.touch_product_list() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.created_at := old.created_at;
  new.updated_at := now();
  return new;
end;
$$;
create trigger product_list_updated before update on public.product_lists
for each row execute function public.touch_product_list();

alter table public.product_lists enable row level security;
alter table public.list_items enable row level security;
revoke all on public.product_lists, public.list_items from anon, authenticated;
grant select, insert, delete on public.product_lists to authenticated;
-- owner_id fica fora: a lista não troca de dono.
grant update(name, description, visibility) on public.product_lists to authenticated;
grant select, insert, delete on public.list_items to authenticated;

create policy product_lists_read on public.product_lists for select to authenticated
  using (owner_id = (select auth.uid()) or visibility = 'public');
create policy product_lists_own_insert on public.product_lists for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select public.is_confirmed_account()));
create policy product_lists_own_update on public.product_lists for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and (select public.is_confirmed_account()));
-- Excluir a própria lista não exige confirmação: o dono sempre pode apagar seus dados.
create policy product_lists_own_delete on public.product_lists for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Itens herdam a visibilidade da lista; vale também para embed/join pelo PostgREST.
create policy list_items_read on public.list_items for select to authenticated
  using (exists (
    select 1 from public.product_lists l
    where l.id = list_id and (l.owner_id = (select auth.uid()) or l.visibility = 'public')
  ));
create policy list_items_own_insert on public.list_items for insert to authenticated
  with check (
    (select public.is_confirmed_account())
    and exists (select 1 from public.product_lists l where l.id = list_id and l.owner_id = (select auth.uid()))
  );
create policy list_items_own_delete on public.list_items for delete to authenticated
  using (exists (select 1 from public.product_lists l where l.id = list_id and l.owner_id = (select auth.uid())));

revoke all on function public.is_confirmed_account() from public, anon;
grant execute on function public.is_confirmed_account() to authenticated;
revoke all on function public.touch_product_list() from public, anon, authenticated;
commit;

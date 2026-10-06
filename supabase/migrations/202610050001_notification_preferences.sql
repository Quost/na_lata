begin;
create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  replies boolean not null default false,
  new_followers boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function public.touch_notification_preferences() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.created_at := old.created_at;
  new.updated_at := now();
  return new;
end;
$$;
create trigger notification_preferences_updated
before update on public.notification_preferences
for each row execute function public.touch_notification_preferences();

alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from anon, authenticated;
grant select on public.notification_preferences to authenticated;
grant insert(user_id, replies, new_followers) on public.notification_preferences to authenticated;
grant update(user_id, replies, new_followers) on public.notification_preferences to authenticated;

create policy notification_preferences_own_read on public.notification_preferences
  for select to authenticated using (user_id = (select auth.uid()));
create policy notification_preferences_own_insert on public.notification_preferences
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy notification_preferences_own_update on public.notification_preferences
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on function public.touch_notification_preferences() from public, anon, authenticated;
commit;

-- MOD01: moderação de avaliações com papel protegido e auditoria.
-- Executar UMA vez no SQL Editor, depois das migrações de 202610050001/0002.
-- Transacional: se algo falhar, nada é aplicado.
begin;

-- 1. Papel de moderador -------------------------------------------------
-- Só o professor (SQL Editor/Dashboard) insere aqui. O cliente não tem
-- nenhum privilégio na tabela, então não lê, não se promove e não se remove.
create table public.moderators (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.moderators enable row level security;
revoke all on public.moderators from public, anon, authenticated;

-- Identidade sempre conferida no servidor por auth.uid().
create function public.is_moderator() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.moderators m where m.user_id = (select auth.uid())
  );
$$;

-- 2. Visibilidade das avaliações ----------------------------------------
-- Ocultar é reversível e não apaga autoria, nota nem comentário.
alter table public.reviews
  add column visibility text not null default 'visible'
  check (visibility in ('visible', 'hidden'));
create index reviews_visible_barcode_idx
  on public.reviews(barcode) where visibility = 'visible';
-- Nenhum GRANT de update em visibility: só as funções abaixo alteram.

drop policy reviews_read on public.reviews;
create policy reviews_read on public.reviews for select to authenticated using (
  visibility = 'visible'
  or user_id = (select auth.uid())
  or (select public.is_moderator())
);
drop policy reviews_own_insert on public.reviews;
create policy reviews_own_insert on public.reviews for insert to authenticated
  with check (user_id = (select auth.uid()) and visibility = 'visible');

-- updated_at passa a mudar só quando nota/comentário mudam: ocultar ou
-- restaurar não marca a avaliação como "editada".
create or replace function public.touch_review() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.created_at := old.created_at;
  if (new.rating, new.comment) is distinct from (old.rating, old.comment) then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;

-- 3. Estados e decisão das denúncias ------------------------------------
alter table public.reports drop constraint reports_status_check;
alter table public.reports
  add column decided_by uuid references public.profiles(id) on delete set null,
  add column decided_at timestamptz,
  add column decision_note text;
-- O antigo 'reviewed' não guardava decisão: vira 'dismissed' sem ator.
update public.reports
   set status = 'dismissed',
       decided_at = now(),
       decision_note = 'Migrado do status reviewed (sem registro de decisão).'
 where status = 'reviewed';
alter table public.reports
  add constraint reports_status_check
    check (status in ('pending', 'dismissed', 'actioned')),
  add constraint reports_decision_check check (
    (status = 'pending' and decided_at is null and decided_by is null
      and decision_note is null)
    or (status <> 'pending' and decided_at is not null
      and char_length(btrim(decision_note)) between 3 and 500)
  );
create index reports_pending_idx on public.reports(created_at)
  where status = 'pending';
-- Leitura própria continua (reports_own_read); moderador lê a fila global.
create policy reports_moderator_read on public.reports for select
  to authenticated using ((select public.is_moderator()));

-- 4. Trilha de auditoria imutável ---------------------------------------
-- Sem FK em actor/review/report: a trilha sobrevive à exclusão do conteúdo.
create table public.moderation_log (
  id bigint generated always as identity primary key,
  actor_id uuid not null,
  action text not null
    check (action in ('hide_review', 'restore_review', 'dismiss_report')),
  review_id uuid,
  report_id uuid,
  review_author_id uuid,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  created_at timestamptz not null default now(),
  check (review_id is not null or report_id is not null)
);
alter table public.moderation_log enable row level security;
revoke all on public.moderation_log from public, anon, authenticated;
grant select on public.moderation_log to authenticated;
create policy moderation_log_moderator_read on public.moderation_log
  for select to authenticated using ((select public.is_moderator()));

create function public.moderation_log_immutable() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'A trilha de moderação é imutável.' using errcode = '42501';
end;
$$;
create trigger moderation_log_no_change
  before update or delete on public.moderation_log
  for each row execute function public.moderation_log_immutable();

-- 5. Operações do moderador ---------------------------------------------
-- Retornam 'ok', 'unchanged' (já estava assim) ou 'not_found'.
-- Usuário comum recebe 42501; motivo inválido recebe 23514.
create function public.moderate_review(
  p_review_id uuid, p_hidden boolean, p_reason text
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := (select auth.uid());
  v_reason text := btrim(coalesce(p_reason, ''));
  v_target text := case when p_hidden then 'hidden' else 'visible' end;
  v_review public.reviews%rowtype;
begin
  if v_actor is null or not public.is_moderator() then
    raise exception 'Somente moderadores podem moderar avaliações.'
      using errcode = '42501';
  end if;
  if p_hidden is null or char_length(v_reason) not between 3 and 500 then
    raise exception 'Informe o motivo da decisão (3 a 500 caracteres).'
      using errcode = '23514';
  end if;
  select * into v_review from public.reviews
   where id = p_review_id for update;
  if not found then
    return 'not_found';
  end if;
  if v_review.visibility = v_target then
    return 'unchanged';
  end if;
  update public.reviews set visibility = v_target where id = p_review_id;
  insert into public.moderation_log
    (actor_id, action, review_id, review_author_id, reason)
  values (
    v_actor,
    case when p_hidden then 'hide_review' else 'restore_review' end,
    p_review_id, v_review.user_id, v_reason
  );
  if p_hidden then
    update public.reports
       set status = 'actioned', decided_by = v_actor, decided_at = now(),
           decision_note = v_reason
     where review_id = p_review_id and status = 'pending';
  end if;
  return 'ok';
end;
$$;

create function public.dismiss_report(p_report_id uuid, p_reason text)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := (select auth.uid());
  v_reason text := btrim(coalesce(p_reason, ''));
  v_report public.reports%rowtype;
begin
  if v_actor is null or not public.is_moderator() then
    raise exception 'Somente moderadores podem decidir denúncias.'
      using errcode = '42501';
  end if;
  if char_length(v_reason) not between 3 and 500 then
    raise exception 'Informe o motivo da decisão (3 a 500 caracteres).'
      using errcode = '23514';
  end if;
  select * into v_report from public.reports
   where id = p_report_id for update;
  if not found then
    return 'not_found';
  end if;
  if v_report.status <> 'pending' then
    return 'unchanged';
  end if;
  update public.reports
     set status = 'dismissed', decided_by = v_actor, decided_at = now(),
         decision_note = v_reason
   where id = p_report_id;
  insert into public.moderation_log
    (actor_id, action, review_id, report_id, review_author_id, reason)
  select v_actor, 'dismiss_report', v_report.review_id, p_report_id,
         r.user_id, v_reason
    from public.reviews r where r.id = v_report.review_id;
  return 'ok';
end;
$$;

revoke all on function public.is_moderator() from public, anon;
revoke all on function public.moderate_review(uuid, boolean, text) from public, anon;
revoke all on function public.dismiss_report(uuid, text) from public, anon;
revoke all on function public.moderation_log_immutable() from public, anon, authenticated;
grant execute on function public.is_moderator() to authenticated;
grant execute on function public.moderate_review(uuid, boolean, text) to authenticated;
grant execute on function public.dismiss_report(uuid, text) to authenticated;
commit;

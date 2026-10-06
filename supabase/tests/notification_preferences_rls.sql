begin;
insert into auth.users (id) values
 ('d4d4d4d4-4444-4444-8444-444444444444'),
 ('e5e5e5e5-5555-4555-8555-555555555555');
set local role authenticated;

select set_config('request.jwt.claim.sub', 'e5e5e5e5-5555-4555-8555-555555555555', true);
do $$ begin
 begin
  insert into public.notification_preferences(user_id, replies) values ('d4d4d4d4-4444-4444-8444-444444444444', true);
  raise exception 'Aceitou autor falso';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', 'd4d4d4d4-4444-4444-8444-444444444444', true);
do $$ begin
 if exists(select 1 from public.notification_preferences) then raise exception 'Havia linha antes da escolha'; end if;
 insert into public.notification_preferences(user_id, replies) values ('d4d4d4d4-4444-4444-8444-444444444444', true);
 insert into public.notification_preferences(user_id, replies, new_followers) values ('d4d4d4d4-4444-4444-8444-444444444444', true, true)
  on conflict (user_id) do update set user_id = excluded.user_id, replies = excluded.replies, new_followers = excluded.new_followers;
 if (select count(*) from public.notification_preferences where replies and new_followers) <> 1 then raise exception 'Upsert falhou'; end if;
end $$;

select set_config('request.jwt.claim.sub', 'e5e5e5e5-5555-4555-8555-555555555555', true);
do $$
declare affected integer;
begin
 if exists(select 1 from public.notification_preferences) then raise exception 'Vazou preferência alheia'; end if;
 update public.notification_preferences set replies = false where user_id = 'd4d4d4d4-4444-4444-8444-444444444444';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Alterou preferência alheia'; end if;
 begin
  delete from public.notification_preferences where user_id = 'd4d4d4d4-4444-4444-8444-444444444444';
  raise exception 'Aceitou delete';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', 'd4d4d4d4-4444-4444-8444-444444444444', true);
do $$ begin
 begin
  update public.notification_preferences set user_id = 'e5e5e5e5-5555-4555-8555-555555555555';
  raise exception 'Trocou o dono';
 exception when insufficient_privilege then null; end;
 begin
  update public.notification_preferences set created_at = now() - interval '1 day';
  raise exception 'Alterou created_at';
 exception when insufficient_privilege then null; end;
 if (select count(*) from public.notification_preferences where replies and new_followers) <> 1 then raise exception 'Preferência de A foi alterada'; end if;
end $$;

set local role anon;
do $$ begin
 begin
  perform * from public.notification_preferences;
  raise exception 'Permitiu leitura sem sessão';
 exception when insufficient_privilege then null; end;
end $$;
rollback;

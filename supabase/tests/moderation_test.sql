-- MOD01. Executar no SQL Editor como postgres, depois das migrações.
-- Tudo é revertido ao final. Qualquer falha interrompe com a mensagem do caso.
-- A = autora, B = usuário comum, M = moderador.
begin;
insert into auth.users (id) values
 ('a1a1a1a1-1111-4111-8111-111111111111'),
 ('b2b2b2b2-2222-4222-8222-222222222222'),
 ('d4d4d4d4-4444-4444-8444-444444444444');
insert into public.moderators(user_id) values ('d4d4d4d4-4444-4444-8444-444444444444');
set local role authenticated;

-- A cria dois produtos e duas avaliações.
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
insert into public.products(barcode,name) values
 ('00000000777771','Produto moderação 1'), ('00000000777772','Produto moderação 2'),
 ('00000000777773','Produto moderação 3');
insert into public.reviews(id,barcode,user_id,rating,comment) values
 ('e5e5e5e5-5555-4555-8555-555555555551','00000000777771','a1a1a1a1-1111-4111-8111-111111111111',1,'Comentário abusivo'),
 ('e5e5e5e5-5555-4555-8555-555555555552','00000000777772','a1a1a1a1-1111-4111-8111-111111111111',4,'Comentário normal');
do $$ begin
 begin
  insert into public.reviews(barcode,user_id,rating,visibility)
  values ('00000000777773','a1a1a1a1-1111-4111-8111-111111111111',3,'hidden');
  raise exception 'Cliente criou avaliação já oculta';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.reviews(id,barcode,user_id,rating,comment) values
 ('e5e5e5e5-5555-4555-8555-555555555553','00000000777773','a1a1a1a1-1111-4111-8111-111111111111',5,'Terceira');

-- B denuncia as duas e tenta se promover ou decidir.
select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
insert into public.reports(id,review_id,user_id,reason) values
 ('f6f6f6f6-6666-4666-8666-666666666661','e5e5e5e5-5555-4555-8555-555555555551','b2b2b2b2-2222-4222-8222-222222222222','ofensa'),
 ('f6f6f6f6-6666-4666-8666-666666666662','e5e5e5e5-5555-4555-8555-555555555552','b2b2b2b2-2222-4222-8222-222222222222','spam');
do $$
declare n integer;
begin
 if public.is_moderator() then raise exception 'Usuário comum aparece como moderador'; end if;
 begin
  insert into public.moderators(user_id) values ('b2b2b2b2-2222-4222-8222-222222222222');
  raise exception 'Usuário comum se promoveu';
 exception when insufficient_privilege then null; end;
 begin
  perform * from public.moderators;
  raise exception 'Usuário comum leu a tabela de moderadores';
 exception when insufficient_privilege then null; end;
 begin
  update public.reports set status = 'dismissed' where review_id = 'e5e5e5e5-5555-4555-8555-555555555551';
  raise exception 'Usuário comum alterou status de denúncia';
 exception when insufficient_privilege then null; end;
 begin
  update public.reviews set visibility = 'hidden' where id = 'e5e5e5e5-5555-4555-8555-555555555551';
  raise exception 'Usuário comum ocultou avaliação';
 exception when insufficient_privilege then null; end;
 begin
  perform public.moderate_review('e5e5e5e5-5555-4555-8555-555555555551', true, 'tentativa');
  raise exception 'Usuário comum chamou moderate_review';
 exception when insufficient_privilege then null; end;
 begin
  perform public.dismiss_report('f6f6f6f6-6666-4666-8666-666666666661', 'tentativa');
  raise exception 'Usuário comum chamou dismiss_report';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.reports(review_id,user_id,reason,status)
  values ('e5e5e5e5-5555-4555-8555-555555555553','b2b2b2b2-2222-4222-8222-222222222222','outro','dismissed');
  raise exception 'Denúncia nasceu decidida';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.reports(review_id,user_id,reason,decided_at)
  values ('e5e5e5e5-5555-4555-8555-555555555553','b2b2b2b2-2222-4222-8222-222222222222','outro',now());
  raise exception 'Denúncia pendente aceitou data de decisão';
 exception when check_violation then null; end;
 select count(*) into n from public.moderation_log;
 if n <> 0 then raise exception 'Usuário comum leu a trilha de moderação'; end if;
 select count(*) into n from public.reports;
 if n <> 2 then raise exception 'B deveria ver só as próprias 2 denúncias, viu %', n; end if;
end $$;

-- A não lê a fila global.
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
do $$ begin
 if exists (select 1 from public.reports) then raise exception 'A leu denúncias alheias'; end if;
end $$;

-- M modera.
select set_config('request.jwt.claim.sub', 'd4d4d4d4-4444-4444-8444-444444444444', true);
do $$
declare n integer; r record;
begin
 if not public.is_moderator() then raise exception 'Moderador não reconhecido'; end if;
 select count(*) into n from public.reports where status = 'pending';
 if n <> 2 then raise exception 'Moderador deveria ver 2 denúncias pendentes, viu %', n; end if;
 begin
  perform public.moderate_review('e5e5e5e5-5555-4555-8555-555555555551', true, '  ');
  raise exception 'Aceitou decisão sem motivo';
 exception when check_violation then null; end;
 if public.moderate_review('e5e5e5e5-5555-4555-8555-555555555551', true, 'Ofensa confirmada') <> 'ok' then
  raise exception 'Ocultar falhou'; end if;
 if public.moderate_review('e5e5e5e5-5555-4555-8555-555555555551', true, 'Ofensa confirmada') <> 'unchanged' then
  raise exception 'Ocultar de novo não foi idempotente'; end if;
 if public.moderate_review('00000000-0000-4000-8000-000000000000', true, 'Inexistente') <> 'not_found' then
  raise exception 'Alvo inexistente não retornou not_found'; end if;
 select * into r from public.reports where id = 'f6f6f6f6-6666-4666-8666-666666666661';
 if r.status <> 'actioned' or r.decided_by <> 'd4d4d4d4-4444-4444-8444-444444444444'
    or r.decided_at is null or r.decision_note <> 'Ofensa confirmada' then
  raise exception 'Denúncia não registrou a decisão'; end if;
 select count(*) into n from public.moderation_log
  where action = 'hide_review' and actor_id = 'd4d4d4d4-4444-4444-8444-444444444444'
    and review_author_id = 'a1a1a1a1-1111-4111-8111-111111111111';
 if n <> 1 then raise exception 'Trilha deveria ter 1 ocultação, tem %', n; end if;
 select count(*) into n from public.reviews where id = 'e5e5e5e5-5555-4555-8555-555555555551';
 if n <> 1 then raise exception 'Moderador não vê avaliação oculta'; end if;
 begin
  update public.moderation_log set reason = 'apagar rastro';
  raise exception 'Moderador alterou a trilha';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.moderation_log;
  raise exception 'Moderador apagou a trilha';
 exception when insufficient_privilege then null; end;
end $$;

-- B não vê a oculta; A (autora) vê, edita e continua sem poder restaurar.
select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
do $$ begin
 if exists (select 1 from public.reviews where id = 'e5e5e5e5-5555-4555-8555-555555555551') then
  raise exception 'Avaliação oculta apareceu para outro usuário'; end if;
 if (select count(*) from public.reviews where barcode in ('00000000777771','00000000777772')) <> 1 then
  raise exception 'Estatística pública incluiu avaliação oculta'; end if;
end $$;
select set_config('request.jwt.claim.sub', 'a1a1a1a1-1111-4111-8111-111111111111', true);
do $$
declare v text; u timestamptz; u2 timestamptz;
begin
 select visibility, updated_at into v, u from public.reviews where id = 'e5e5e5e5-5555-4555-8555-555555555551';
 if v is distinct from 'hidden' then raise exception 'Autora deveria ver a própria avaliação oculta'; end if;
 begin
  update public.reviews set visibility = 'visible' where id = 'e5e5e5e5-5555-4555-8555-555555555551';
  raise exception 'Autora restaurou a própria avaliação';
 exception when insufficient_privilege then null; end;
 update public.reviews set comment = 'Comentário corrigido' where id = 'e5e5e5e5-5555-4555-8555-555555555551';
 select visibility, updated_at into v, u2 from public.reviews where id = 'e5e5e5e5-5555-4555-8555-555555555551';
 if v <> 'hidden' then raise exception 'Editar tornou a avaliação visível'; end if;
end $$;

-- M restaura e arquiva a segunda denúncia.
select set_config('request.jwt.claim.sub', 'd4d4d4d4-4444-4444-8444-444444444444', true);
do $$
declare n integer;
begin
 if public.moderate_review('e5e5e5e5-5555-4555-8555-555555555551', false, 'Comentário corrigido pela autora') <> 'ok' then
  raise exception 'Restaurar falhou'; end if;
 if public.dismiss_report('f6f6f6f6-6666-4666-8666-666666666662', 'Não é spam') <> 'ok' then
  raise exception 'Arquivar denúncia falhou'; end if;
 if public.dismiss_report('f6f6f6f6-6666-4666-8666-666666666662', 'Não é spam') <> 'unchanged' then
  raise exception 'Arquivar de novo não foi idempotente'; end if;
 if (select visibility from public.reviews where id = 'e5e5e5e5-5555-4555-8555-555555555552') <> 'visible' then
  raise exception 'Arquivar denúncia ocultou a avaliação'; end if;
 select count(*) into n from public.moderation_log;
 if n <> 3 then raise exception 'Trilha deveria ter 3 decisões, tem %', n; end if;
end $$;

-- Restaurada volta a aparecer para B.
select set_config('request.jwt.claim.sub', 'b2b2b2b2-2222-4222-8222-222222222222', true);
do $$ begin
 if not exists (select 1 from public.reviews where id = 'e5e5e5e5-5555-4555-8555-555555555551') then
  raise exception 'Avaliação restaurada não voltou'; end if;
end $$;

-- Nem o dono do banco altera a trilha.
reset role;
do $$ begin
 begin
  update public.moderation_log set reason = 'adulterado';
  raise exception 'postgres alterou a trilha';
 exception when insufficient_privilege then null; end;
end $$;
rollback;

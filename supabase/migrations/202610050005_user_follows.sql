-- Tabela para persistir a relação de seguir pessoas (SOC01)
create table user_follows (
  follower_id uuid not null references auth.users (id) on delete cascade,
  followed_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  constraint user_follows_not_self check (follower_id != followed_id)
);

-- Habilitar Row Level Security
alter table user_follows enable row level security;

-- Política de leitura: qualquer usuário (mesmo anônimo/visitante) pode ver quem segue quem
create policy "Relações de seguir são públicas"
on user_follows for select
using (true);

-- Política de inserção: usuário só pode inserir relações onde ele é o follower
create policy "Usuários podem seguir outros"
on user_follows for insert
with check (auth.uid() = follower_id);

-- Política de exclusão: usuário só pode remover relações onde ele é o follower
create policy "Usuários podem deixar de seguir"
on user_follows for delete
using (auth.uid() = follower_id);

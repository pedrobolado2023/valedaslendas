-- Guerra dos Reinos (semanal): o servidor do jogo guarda aqui os pontos de cada reino e quem está com a Coroa.
-- Rodar no Supabase: SQL Editor > New query > colar > Run. Só o servidor (chave secreta) lê e grava.
create table if not exists public.kingdom_war (
  id int primary key default 1,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.kingdom_war enable row level security;

-- Rodar no Supabase (SQL Editor) quando o servidor do jogo estiver no ar: a partir daí só o servidor
-- (chave service_role) grava os saves; o navegador só consegue LER o próprio save. Evita trapaça pelo navegador.
drop policy if exists "dono grava o save" on public.saves;
drop policy if exists "dono atualiza o save" on public.saves;
drop policy if exists "dono registra compra" on public.purchases;

-- nomes de herói únicos (o servidor reserva o nome quando o herói é criado)
create table if not exists public.hero_names (
  name_key text primary key,           -- nome em minúsculas
  name text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.hero_names enable row level security;
drop policy if exists "todos leem nomes" on public.hero_names;
create policy "todos leem nomes" on public.hero_names for select using (true);

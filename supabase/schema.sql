-- Vale das Lendas — banco de dados no Supabase.
-- Cada jogador entra com login anônimo (Auth > Anonymous sign-ins ligado) e só enxerga/edita a própria linha.

create table if not exists public.saves (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null,
  level int not null default 1,
  class text not null default '',
  saved_at text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.purchases (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  item text not null,
  price int not null,
  at text not null default '',
  created_at timestamptz not null default now()
);

alter table public.saves enable row level security;
alter table public.purchases enable row level security;

drop policy if exists "dono le o save" on public.saves;
create policy "dono le o save" on public.saves for select using ((select auth.uid()) = user_id);
drop policy if exists "dono grava o save" on public.saves;
create policy "dono grava o save" on public.saves for insert with check ((select auth.uid()) = user_id);
drop policy if exists "dono atualiza o save" on public.saves;
create policy "dono atualiza o save" on public.saves for update using ((select auth.uid()) = user_id);

drop policy if exists "dono le as compras" on public.purchases;
create policy "dono le as compras" on public.purchases for select using ((select auth.uid()) = user_id);
drop policy if exists "dono registra compra" on public.purchases;
create policy "dono registra compra" on public.purchases for insert with check ((select auth.uid()) = user_id);

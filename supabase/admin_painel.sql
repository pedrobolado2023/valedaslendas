-- Painel do administrador (página /admin). Só contas com app_metadata.admin = true leem e escrevem.
-- O servidor do jogo (chave secreta) lê os comandos, executa e grava o resultado e o estado a cada 10 s.

create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false)
$$;

create table if not exists public.admin_commands (
  id bigint generated always as identity primary key,
  cmd text not null,
  args jsonb not null default '{}',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  done boolean not null default false,
  result text not null default ''
);
alter table public.admin_commands enable row level security;
drop policy if exists "admin le comandos" on public.admin_commands;
create policy "admin le comandos" on public.admin_commands for select using (public.is_admin());
drop policy if exists "admin cria comandos" on public.admin_commands;
create policy "admin cria comandos" on public.admin_commands for insert with check (public.is_admin() and done = false);

create table if not exists public.server_status (
  id int primary key default 1,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.server_status enable row level security;
drop policy if exists "admin le estado" on public.server_status;
create policy "admin le estado" on public.server_status for select using (public.is_admin());

-- Configuração do jogo (multiplicadores, mensagem do dia, manutenção). O servidor aplica e manda aos jogadores.
create table if not exists public.game_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.game_config enable row level security;
drop policy if exists "admin le config" on public.game_config;
create policy "admin le config" on public.game_config for select using (public.is_admin());

create table if not exists public.bans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  reason text not null default '',
  created_at timestamptz not null default now()
);
alter table public.bans enable row level security;
drop policy if exists "admin le banidos" on public.bans;
create policy "admin le banidos" on public.bans for select using (public.is_admin());

-- Painel lê heróis (nível/classe) para a lista de jogadores.
drop policy if exists "admin le nomes" on public.hero_names;
create policy "admin le nomes" on public.hero_names for select using (public.is_admin());

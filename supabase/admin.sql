-- Marca uma conta como administrador do jogo (menu F1 liberado no jogo publicado).
-- Rodar no Supabase: SQL Editor > New query > colar > Run. Depois sair e entrar de novo no jogo.
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"admin": true}'::jsonb
where email = 'pedrohenriquebonfim156@gmail.com';

-- conferir:
select email, raw_app_meta_data->>'admin' as admin from auth.users where email = 'pedrohenriquebonfim156@gmail.com';

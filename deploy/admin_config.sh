#!/bin/sh
# Gera admin/config.js (endereço e chave pública do Supabase) a partir do supabase.cfg. Uso: sh deploy/admin_config.sh <saída>
url=$(sed -n 's/^url="\(.*\)"/\1/p' supabase.cfg | head -1)
key=$(sed -n 's/^anon_key="\(.*\)"/\1/p' supabase.cfg | head -1)
printf 'window.VALE_SB = {url: "%s", key: "%s"};\n' "$url" "$key" > "$1"

#!/bin/sh
# Gera admin/config.js (endereço e chave pública do Supabase) a partir do supabase.cfg. Uso: sh deploy/admin_config.sh <saída>
# tr tira o \r do fim das linhas (supabase.cfg salvo no Windows), senão a chave quebra o JavaScript.
url=$(tr -d '\r' < supabase.cfg | sed -n 's/^url="\(.*\)"/\1/p' | head -1)
key=$(tr -d '\r' < supabase.cfg | sed -n 's/^anon_key="\(.*\)"/\1/p' | head -1)
printf 'window.VALE_SB = {url: "%s", key: "%s"};\n' "$url" "$key" > "$1"

# Colocar o Vale das Lendas online (Easypanel)

São 2 serviços do tipo **App** no mesmo projeto do Easypanel, os dois vindos do GitHub
(`pedrobolado2023/valedaslendas`, branch `main`).

## 1. Servidor do jogo
- Fonte: GitHub → Build: **Dockerfile** → caminho `deploy/Dockerfile.server`
- Ambiente (Environment):
  - `SUPABASE_SERVICE_KEY` = chave **service_role** (Supabase → Project Settings → API Keys). É secreta: só aqui.
  - `PORT` = `8080`
- Domínio: por exemplo `server.seudominio.com` → porta **8080** (HTTPS ligado; o WebSocket vira `wss://`).

## 2. Página do jogo
- Fonte: GitHub → Build: **Dockerfile** → caminho `deploy/Dockerfile.web`
- Build Args: `VALE_SERVER_URL` = `wss://server.seudominio.com` (o domínio do serviço 1)
- Domínio: por exemplo `jogo.seudominio.com` → porta **80**
- O primeiro build demora (baixa o Godot e o pacote de templates, ~1 GB).

## Depois
- Abra `https://jogo.seudominio.com`, crie a conta e jogue.
- Logs do servidor (Easypanel → serviço 1 → Logs) mostram quem entrou/saiu.
- VPS no Brasil (São Paulo) e o projeto do Supabase na mesma região deixam o atraso baixo.

## O que já é online
- Login por e-mail/senha (Supabase) e save guardado pelo servidor no banco.
- Jogadores do mesmo mapa se veem (posição, classe, equipamento, montaria, nome).
- Boss global com a vida no servidor: todos batem no mesmo dragão.

## Ainda local (cada jogador no seu)
- Monstros comuns, masmorras, drops, refino e loja rodam no navegador de cada um
  (próximo passo: passar para o servidor para evitar trapaça e caçar junto).

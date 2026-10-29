# Vale das Lendas — contexto do projeto (para o Claude Code)

Jogo de RPG/MMORPG 2.5D em **Godot 4.3+** (GDScript) com modelos 3D gerados por código no **Blender 5.2** (Python/bpy).
Estilo visual inspirado em Hades: câmera isométrica ortográfica a 45°, sombreamento cartoon (toon) com contorno,
cenário escuro com luzes coloridas. Dono do projeto: brasileiro, fala português — responder sempre em português.

## Como rodar
- Abrir `project.godot` no Godot 4.3+ e apertar F5 (cena principal `main.tscn` → `scripts/game.gd`).
- Na primeira abertura o Godot importa modelos/texturas/sons (~1 min).
- Testes sem tela: `godot --headless --path . -s <script_de_teste.gd>` (padrão usado: scripts SceneTree que
  instanciam `main.tscn`, chamam `start_game("druida", {})` e verificam estado).

## Estrutura
- `scripts/data.gd` — TODOS os números: classes, 24 skills, inimigos, 4 mapas, 12 zonas, 12 missões de história,
  raridades, limites das missões, `ADMIN_ENABLED`. Para balancear, mexer aqui.
- `scripts/game.gd` — jogo principal: câmera, mapas/portal, missões (história + quadro), modo automático, drops, save, admin.
- `scripts/player.gd` — herói: movimento, ataque básico, skills, passivas, buffs, XP, equipamentos/skins e efeitos das skins.
- `scripts/skills.gd` — efeito de cada tipo de skill. `scripts/enemy.gd`, `projectile.gd`, `loot.gd`, `zone.gd`, `npc.gd`.
- `scripts/autopilot.gd` — modo automático. `scripts/mission_book.gd` — diárias/semanais/mensais. `scripts/save_game.gd`.
- `scripts/world.gd` — monta cada mapa a partir de `GameData.MAPS` (chão pintado, trilhas, vegetação, lago, acampamento).
- `scripts/model_kit.gd` — carrega `.glb`, converte materiais para o shader toon, animações (idle/walk/run/attack).
- `scripts/ui/` — HUD, minimapa, diálogo, painel de skills (K), quadro de missões (J), equipamento (I), admin (F1), menu.
- `shaders/` — toon, outline, terrain, foliage_card, water, slash, trail.
- `blender/` — geração dos modelos (ver abaixo). `tools/` — texturas e sons por código. `docs/` — imagens e vídeos.

## Regras do jogo já implementadas
- 4 classes (substituíram Guerreiro/Lanceiro/Arqueiro/Mago; saves antigos são convertidos):
  **Druida, Assassino, Mecânico, Náutico**, cada uma com 6 skills (lista do dono), liberadas nos níveis 1/3/6/10/15/20.
  Passivas: Espírito da Coruja (Druida), Sobrecarga de Vapor (Mecânico), Presença Abissal (Náutico).
- Nível máximo 60; 1 ponto de skill por nível; skill até nível 10. **A partir do nível 31 todo XP vale 10x menos.**
  (O dono quer chegar a 1000 níveis no futuro.)
- 4 mapas: Vale das Lendas (1-15), Deserto Escarlate (16-30), Picos Gelados (31-45), Abismo Vulcânico (46-60),
  3 áreas com chefe cada; viagem pelo Portal do acampamento.
- Missões do quadro: diárias até 30/dia; semanais até 150/semana (pode fazer todas de uma vez);
  mensais até 900/mês liberadas 30 por dia (não dá para adiantar). Usam a data do computador.
- Modo automático ("Ir automático"): faz história (aceita, vai, mata, chefe, entrega, viaja de mapa),
  quando o nível não alcança faz diárias → semanais → mensais, e quando acaba tudo caça. Não para sozinho.
- Equipamentos: arma e armadura em Comum/Rara/Épica/Lendária com bônus; todo herói começa com as 4 skins
  e a Lendária equipada. Drops escassos. Loja pay-to-win ainda NÃO feita.
- Menu de administrador (F1): itens, nível, ouro, skills, imortal, trocar classe, viajar, pular missões, zerar limites.
- Salva sozinho em `user://vale_das_lendas_save.json`.

## Modelos 3D (blender/)
- `make_models.py` — base: monstros antigos, cenário do Vale, NPCs. `make_maps.py` — monstros/cenário dos mapas novos.
- `make_heroes.py` — skins por raridade de Assassino/Mecânico/Náutico (estilo antigo, "blocado") + armas de todas as
  classes + mascotes (coruja, água-viva, peixe). **Pula o corpo da Druida.**
- **Druida humanizada (novo padrão de qualidade):** `make_druid_mpfb.py` + `mpfb_kit.py`, usando o **MPFB2**
  (MakeHuman Plugin For Blender, assets CC0). Corpo humano liso, esqueleto `game_engine` (53 ossos, compatível
  com nomes estilo Unreal/Mixamo), olhos reais do MakeHuman, roupas recortadas dos moldes `helper-tights`/`helper-skirt`
  (acompanham o corpo), peças rígidas presas a ossos, mão direita fechada em volta do cajado (nó "Weapon" é uma
  malha minúscula porque o Godot descarta nós vazios presos a ossos), animações idle/walk/run/attack de corpo inteiro.
  - Instalação: `git clone https://github.com/makehumancommunity/mpfb2` e instalar `src/mpfb` como extensão
    do Blender (`extensions/user_default/mpfb`, ativar com `addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)`).
  - Olhos: pasta `makehuman/data` de https://github.com/makehumancommunity/makehuman → variável `MH_DATA`.
  - Rodar: `MH_DATA=<.../makehuman/data> blender -b -P blender/make_druid_mpfb.py` (ou `python` com `pip install bpy==5.2.3`).
  - Convenções: cores passadas em sRGB (convertidas para linear em `color_mat`); personagem olha +Y no Blender
    (nó raiz gira 180° porque o MPFB olha -Y); escala 1,25 (~2,0 de altura).
  - Sinais de rotação medidos (eixos do mundo antes do giro): braço/perna para frente = negativo em X;
    joelho dobra = positivo em X; tronco inclina para frente = positivo em X; dedos fecham = +X local (`CURL_SIGN=1`).

- **Assassino humanizado:** `make_assassin_mpfb.py` (reaproveita funções de `make_druid_mpfb.py`). Homem magro,
  guarda de combate agachada, ataque em golpe duplo. Nó "Weapon" na mão direita com a lâmina em **-Z** (sai pelo lado
  do polegar, como a adaga antiga); a adaga esquerda vem no modelo (nó "AdagaEsquerda" no osso hand_l — não pode
  começar com "Weapon"). Prévias em `docs/assassino_<raridade>.png`.
- **Mecânico humanizado:** `make_mechanic_mpfb.py` (usa funções da Druida e do Assassino). Homem forte; o pulso
  direito é girado para a ferramenta (-Z do nó "Weapon") apontar para frente e um pouco para cima — serve para a
  chave inglesa e para o canhão (a arma tem raridade própria, independente da armadura). Ataque = marretada.
  Lendária tem o nó "Aureola" com o eixo de giro em +Z no Godot (o jogo gira `rotation:z`). Luvas são recortadas
  da própria mão do corpo (`gloves`), porque os moldes de roupa não cobrem os dedos.
- **Náutico humanizado:** `make_nautical_mpfb.py` (usa funções das outras três). Marinheiro barbudo; tridente na
  direita apontando para frente e um pouco para baixo (-Z do "Weapon"); base com pés afastados que o ciclo de pernas
  desfaz ao andar; ataque = estocada com avanço. Barba recortada do próprio rosto (`beard`).
- **Capa com balanço:** `D.cape()` cria 3 ossos próprios (`cape_01..03`, filhos de spine_03) e pesa a capa por altura;
  `mpfb_kit.write_actions` grava o balanço sozinho em toda animação quando esses ossos existem (`cape_motion`:
  ondula parada, levanta andando, voa correndo, chicoteia no ataque). Peças marcadas `o["capa"]` ficam fora das
  medidas do tronco. Luvas sempre com `D.gloves` (recorte da mão do corpo) — `piece()` com ossos da mão sai vazio.
- Ver um modelo exportado de frente/lado/3/4: `C:\Users\pedro\vale-tools\views.py` (Blender, EEVEE, rápido).
- Ferramentas nesta máquina (Windows): `C:\Users\pedro\vale-tools\` — Blender 5.2.3 portátil, Godot 4.3 (console),
  mpfb2, makehuman (só `data/eyes`), backup dos modelos antigos do Assassino em `backup_assassino\`.
  `MH_DATA=C:\Users\pedro\vale-tools\makehuman\makehuman\data`; `TIER=<raridade>` gera só uma raridade.

## Próximos passos combinados com o dono
1. ~~Humanizar as 4 classes com MPFB2~~ — feito (Druida, Assassino, Mecânico, Náutico). Falta o dono testar jogando.
2. Texturas pintadas nas roupas (costuras, desenhos); cabelo melhor (com balanço). Capa com balanço já feita.
3. Animações específicas por skill.
4. Pendentes da ideia original: loja (pay-to-win), multiplayer (precisa de servidor), mais níveis (até 1000).
- Limitações conhecidas: arquivos da Druida têm 4-6 MB cada (dá para reduzir malha); sem GPU no ambiente
  original, por isso nada de IA de imagem→3D (Hunyuan3D precisa de NVIDIA).
- Lembretes: o dono não testou jogando com teclado/mouse ainda; antes de lançar trocar `ADMIN_ENABLED` para false.

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
- **Texturas pintadas das roupas:** `mpfb_kit.paint_clothes` (chamado em `export_glb`) põe `textures/roupa_tecido|couro|metal.png`
  (cinzas, repetem; geradas por código com numpy se não existirem) nos materiais e desdobra cada peça (UV) na mesma
  densidade. Tipo pelo material: metálico ≥ 0,5 → metal; nomes em `LEATHER` → couro; resto → tecido; `NO_TEX` fica liso.
  Barras das roupas: cor por vértice "Barra" (`hem_colors`, escurece perto das bordas); o shader toon só usa a cor por
  vértice com `use_vertex_color` (ligado pelo ModelKit nos personagens). Textura não tira mais o contorno (só olhos).
- **Peças de cabeça lisas:** máscaras, elmos, bonés e capuz usam `D.head_shell` (esfera encolhida até a pele com folga),
  sem copiar nariz/boca. Foto real do Godot das 16 skins: `godot --path . -s C:\Users\pedro\vale-tools\shot_heroes.gd -- saida.png`
  (com janela, `--rendering-driver opengl3`).
- **Animações de skill:** `blender/skill_anims.py` tem uma animação "sk_<id>" por skill ativa (21 no total; passivas
  não têm), somada à pose parada da classe; blocos `K.pulse`, `K.crouch`, `K.merge` em `mpfb_kit.py` (com os sinais
  dos eixos). No jogo, `Player.play_skill` toca a animação depois de `Skills.cast`; enquanto ela toca, os
  `attack_visual`/`leap_to` de dentro da skill não a cortam (o ataque básico corta). Folhas de quadros em
  `docs/skills_<classe>.png` (`C:\Users\pedro\vale-tools\skill_sheet.py`).
- **Até 10 skills por classe** (teclas 1-9 e 0; liberadas nos níveis 1/3/6/10/15/20/25/30/40/50 em
  `GameData.SKILL_UNLOCK`). Tudo usa `player.skill_count()` (HUD, painel K com rolagem, save, admin, autopilot).
  Druida já tem 10: dr7 Granizo Ancestral (`ice_fall`), dr8 Fúria do Trovão (`storm_chain`), dr9 Chuva de Meteoros
  (`meteor_rain`), dr10 Pisão da Morte (`fissure`). Assassino também tem 10: as7 Leque de Adagas (`dagger_fan`),
  as8 Marca da Morte (`death_mark`), as9 Clones das Sombras (`shadow_clones`: cópias escuras do herói com
  `ModelKit.set_tint`), as10 Eclipse Sangrento (`eclipse`). Mecânico também: me7 Enxame de Mísseis (`missiles`,
  projétil "rocket" teleguiado), me8 Lança-Chamas a Vapor (`flamethrower`), me9 Bombardeio Orbital (`orbital`),
  me10 Torre Tesla (`tesla`). Náutico também: na7 Tsunami (`tsunami`), na8 Prisão de Bolhas (`bubbles`), na9
  Tempestade Marítima (`sea_storm`), na10 Fúria do Kraken (`kraken`, tentáculos de segmentos que chicoteiam).
  As skills 7-10 de Assassino/Mecânico/Náutico foram escolhidas por mim com o tema da classe (o dono aprovou seguir).
- **Área das skills:** `GameData.AREA_MULT = 1.4`; sempre ler o raio com `Skills.area(sk)` (nunca `sk["r"]` direto).
- **Efeitos bonitos (`scripts/vfx.gd`, classe `Vfx`):** texturas geradas por código no Godot (brilho, chama em gota,
  fumaça, anel, rachaduras, geada, queimado) + `emit()` (partículas com cor no tempo), `ground_mark()` (Decal),
  `shockwave`, `marker`, `bolt` (raio com galhos), `ice_fall`, `meteor`, `explosion`, `fire_column`, `fissure`.
  Cuidado com o brilho: o ambiente tem glow a partir de 0,85 (world.gd) — cores somadas claras e luzes fortes
  estouram em branco no Vulkan. Decalques não aparecem no modo de compatibilidade (OpenGL); testar no Vulkan.
  Foto das skills dentro do jogo: `godot --path . -s C:\Users\pedro\vale-tools\shot_skills.gd -- saida.png dr7,dr8`.
- Casas do acampamento: `world.gd _house_angle` escolhe o lugar medindo a distância real das trilhas nos cantos da
  casa (as trilhas fazem curva). Foto de cima do acampamento: `C:\Users\pedro\vale-tools\shot_hub.gd -- saida.png gelo`.
- **Boss global (etapa 1, ainda sem servidor):** `GameData.GLOBAL_BOSS` (horários 10h/16h/22h pela hora do PC,
  15 min, recompensas e números das mecânicas) + inimigo `dragon_global` (vida 6000 e dano 30 de propósito, para
  testar; aumentar depois). Mapa de evento `covil` (`"event": true`, zona `arena_dragao` sem monstros normais).
  `scripts/world_events.gd` (agenda, avisos, opção no portal, nasce o dragão, recompensas, `boss_done` no save)
  e `scripts/world_boss.gd` (fases 100/60/30%: sopro em cone, meteoros, voo e queda, dragonetes, anel de fogo;
  mira em todos do grupo "player" — pronto para o multiplayer). Admin F1: "Boss global: começar agora".
  O save nunca guarda o covil: volta para `return_map`. Inimigos podem ter `leash`/`aggro_r` nos dados.
- Próximo: etapa 2 = servidor/multiplayer (Godot sem tela, ENet; boss com vida no servidor), etapa 3 = arena PvP 1x1.
- **Testes nunca podem usar o save do dono:** rodar sempre com a variável `VALE_TESTE=1` (SaveGame usa
  `user://teste_save.json`). Antes disso, testes sobrescreveram o save do dono uma vez (Assassino nv 35 perdido).
- Ícones: `tools/make_textures.py --icons` (rodar com o Python do Blender + `PYTHONPATH=C:\Users\pedro\vale-tools\pylibs`).
- Ver um modelo exportado de frente/lado/3/4: `C:\Users\pedro\vale-tools\views.py` (Blender, EEVEE, rápido).
- Ferramentas nesta máquina (Windows): `C:\Users\pedro\vale-tools\` — Blender 5.2.3 portátil, Godot 4.3 (console),
  mpfb2, makehuman (só `data/eyes`), backup dos modelos antigos do Assassino em `backup_assassino\`.
  `MH_DATA=C:\Users\pedro\vale-tools\makehuman\makehuman\data`; `TIER=<raridade>` gera só uma raridade.

## Próximos passos combinados com o dono
1. ~~Humanizar as 4 classes com MPFB2~~ — feito (Druida, Assassino, Mecânico, Náutico). Falta o dono testar jogando.
2. Cabelo melhor (com balanço). Já feitos: capa com balanço, texturas de tecido/couro/metal e barras nas roupas.
3. ~~Animações específicas por skill~~ — feito (afinar depois de jogar).
3b. ~~10 skills por classe e efeitos novos nas antigas~~ — feito nas 4 classes. Falta o dono jogar e pedir ajustes
    (tamanho/brilho/duração dos efeitos, dano). Decalques grandes com brilho próprio estouram a tela no Vulkan:
    para áreas use `Vfx.marker` (anel discreto). Sprites com `spin: 0` ficam retos (chuva, colunas).
4. Pendentes da ideia original: loja (pay-to-win), multiplayer (precisa de servidor), mais níveis (até 1000).
- Limitações conhecidas: modelos dos heróis têm 5-9 MB cada (dá para reduzir malha). O PC atual do dono tem
  NVIDIA GeForce RTX 2070 — dá para tentar IA de imagem→3D (Hunyuan3D) no futuro.
- Lembretes: o dono não testou jogando com teclado/mouse ainda; antes de lançar trocar `ADMIN_ENABLED` para false
  e `TEST_MP_REGEN` para 0.0 (data.gd; +25 de mana/s só para testes). Mana base subiu 50% e a recarga normal é
  `MP_REGEN_FLAT` + `MP_REGEN_PCT` × mana máxima por segundo.

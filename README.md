# Vale das Lendas — RPG 2.5D (Godot 4 + Blender)

Abra o **Godot 4.3 ou mais novo**, importe esta pasta (`project.godot`) e aperte **F5**.
Na primeira abertura o Godot importa modelos, texturas e sons (pode levar 1 minuto).
Imagens do jogo rodando: `docs/capturas/`. Todas as skins: `docs/skins_todas_as_classes.png`.

## Controles
| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| Clique esquerdo (segurar) / Espaço | ataque básico (o mouse mira) |
| 1 a 6 | skills |
| E ou clique | falar com o NPC, abrir o Quadro de Missões ou usar o Portal |
| J | Quadro de Missões (diárias, semanais, mensais) |
| I | Equipamento e skins |
| K | Skills (gastar pontos) |
| F1 | Menu de administrador |
| M | mapa grande · T: auto-combate · roda do mouse: zoom · Esc: fechar |

## Classes e skills
| Classe | 1 (Nv 1) | 2 (Nv 3) | 3 (Nv 6) | 4 (Nv 10) | 5 (Nv 15) | 6 (Nv 20) |
|---|---|---|---|---|---|---|
| Druida | Chamado das Raízes | Bênção da Flora | Espírito da Coruja (passiva) | Casca de Carvalho | Fúria dos Ventos | Despertar Lendário |
| Assassino | Passo das Sombras | Adagas Envenenadas | Camuflagem Sombria | Dança das Lâminas | Manto do Vazio | Execução Celestial |
| Mecânico | Disparo de Chave | Torreta Automática | Campo de Força Magnético | Sobrecarga de Vapor (passiva) | Drone de Reparo | Colosso de Ouro |
| Náutico | Estocada do Tridente | Correnteza Fluvial | Escudo de Conchas | Presença Abissal (passiva) | Companheiro das Profundezas | Fúria de Poseidon |

Passivas funcionam sozinhas depois de aprendidas. Como ainda não há multiplayer, os efeitos
"para aliados" (cura, velocidade da equipe, drone) valem para o próprio herói.
Antigos saves: Guerreiro vira Assassino, Lanceiro vira Náutico, Arqueiro vira Mecânico e Mago vira Druida.

### Skins (veja `docs/skins_todas_as_classes.png`)
- Druida: túnica simples → capuz e cajado de runas azuis → armadura de folhas com coruja roxa → armadura dourada com chifres de cervo e cajado do sol.
- Assassino: capuz com cachecol → capuz negro, máscara e capa azul → armadura sombria com lâminas roxas e fumaça → elmo de dragão dourado e adagas douradas.
- Mecânico: boné e macacão com chave e engrenagem → óculos, avental e chave elétrica → traje robótico com garra de plasma → armadura mecânica dourada com auréola de engrenagem e canhão.
- Náutico: camisa listrada e arpão → colete azul, tridente e respingos de água → armadura do abismo com raios e água-viva → armadura dourada, tridente de Poseidon e redemoinho com peixes.

### Personagens humanizados (MPFB2) — protótipo começando pela Druida
A Druida agora é gerada com o MPFB2 (MakeHuman Plugin For Blender, modelos CC0): corpo humano liso,
esqueleto com 53 ossos (cotovelos, joelhos, dedos), olhos reais e roupas recortadas dos moldes do próprio
corpo (acompanham o movimento). Arquivos: `blender/mpfb_kit.py` (ferramentas) e `blender/make_druid_mpfb.py`.
Para regenerar: instale o MPFB2 como extensão do Blender, baixe a pasta `makehuman/data` do repositório
github.com/makehumancommunity/makehuman e rode `MH_DATA=<pasta data> blender -b -P blender/make_druid_mpfb.py`.
Comparação: `docs/druida_antes_depois.png`.
A mão direita fecha em volta do cajado (o cajado passa pelo centro do punho) e as animações usam o corpo inteiro:
`idle` (respiração e peso numa perna), `walk`, `run` (usada na velocidade normal do herói) e `attack`.
Vídeo de teste dos movimentos: `docs/druida_movimentos.mp4`.

## Mapas (viaje pelo Portal de cada acampamento)
| Mapa | Níveis | Áreas e chefes |
|---|---|---|
| Vale das Lendas | 1-15 | Campo (Slime Rei), Floresta (Lobo Alfa), Ruínas (Golem Guardião) |
| Deserto Escarlate | 16-30 | Dunas (Rainha Escorpião), Cemitério (Rei Esqueleto), Templo (Colosso de Areia) |
| Picos Gelados | 31-45 | Tundra (Lobo Glacial), Cavernas (Yeti Ancião), Glaciar (Golem de Cristal) |
| Abismo Vulcânico | 46-60 | Fendas (Senhor dos Diabretes), Forja (Titã de Magma), Ninho (Dragão Ancestral) |

12 missões de história, uma por área. O NPC de cada mapa entrega as missões daquele mapa.

## Modo automático (botão "Ir automático")
Aperte uma vez e o herói joga sozinho, sem parar:
1. Faz a missão de história: aceita no NPC, vai até a área, mata os monstros e o chefe, volta e entrega.
   Se a missão é em outro mapa, vai até o portal e viaja sozinho.
2. Se o nível ainda não alcança a próxima história, faz as missões do quadro:
   diárias → semanais → mensais, aceitando a próxima sozinho até acabar cada limite.
3. Quando o nível chega, volta para a história. Se tudo acabou, caça na melhor área para o nível.
Mexer o herói com WASD pausa o automático. Ao subir de nível no automático, os pontos de skill são distribuídos sozinhos.

## Subir de nível
- Nível máximo 60. Cada nível dá 1 ponto de skill (6 skills × nível 10 = 60 pontos).
- **Até o nível 30**: XP normal.
- **A partir do 31**: todo XP ganho (monstros, missões) vale **10 vezes menos**.
- XP vem de monstros, missões de história e missões do quadro.

## Missões do quadro (usam a data do computador)
- **Diárias**: até 30 por dia (renovam à meia-noite).
- **Semanais**: até 150 por semana (renovam na segunda-feira). Pode fazer todas de uma vez.
- **Mensais**: até 900 por mês, **liberadas 30 por dia** (acumulam os dias passados;
  não dá para adiantar o mês).
- Botão **Automático**: o herói faz uma atrás da outra até acabar o limite.
- Cada missão dá XP, ouro e chance de baú com equipamento.

## Equipamentos e skins
Arma e armadura em 4 raridades, com visual próprio em todas as classes.
**Todo herói já começa com as 4 raridades no inventário e a Lendária equipada.**
| Raridade | Visual | Bônus |
|---|---|---|
| Comum | roupa simples | — |
| Rara | aço e azul | +25% ataque / +20% vida, 6% menos dano |
| Épica | escura com brilho roxo | +60% ataque / +50% vida, 12% menos dano |
| Lendária | dourada, brilho, faíscas e aura | +120% ataque / +100% vida, 20% menos dano |
Drops escassos: 3% nos monstros (lendária 0,5% disso), 50% nos chefes, baús nas missões.
Na tela de Equipamento (I) dá para ver a prévia de todas as skins.

## Menu de administrador (F1)
- **Itens**: escolha classe, tipo (arma, armadura ou os dois), raridade (ou todas) e quantidade;
  adicione ao inventário ou adicione e equipe. Também dá todas as skins de todas as classes.
- **Personagem**: definir nível, todas as skills no 10, +100.000 de ouro, vida e mana cheias,
  modo imortal e trocar de classe (mantém nível e progresso).
- **Mundo**: viajar para qualquer mapa sem limite de nível, concluir ou pular missão de história,
  zerar limites das missões do quadro, derrotar inimigos por perto, salvar.
- Para tirar o menu do jogo final: em `scripts/data.gd` troque `ADMIN_ENABLED := true` para `false`.

## Progresso salvo
Salva sozinho (a cada 20 s, ao trocar de mapa, entregar missão, equipar e ao fechar).
No menu aparece **Continuar**. O arquivo fica na pasta de dados do Godot (`user://`).

## Onde mudar as coisas
- Números (classes, skills, inimigos, mapas, missões, raridades, limites): `scripts/data.gd`
- Montagem dos mapas: `scripts/world.gd` · Missões do quadro: `scripts/mission_book.gd`
- Modelos 3D (Blender 5.2 por código, `blender -b -P arquivo.py` ou `pip install bpy`):
  `blender/make_models.py` (base), `blender/make_heroes.py` (16 skins + 16 armas),
  `blender/make_maps.py` (monstros, NPCs e cenário dos mapas novos), `blender/render_item_icons.py` (ícones)
- Texturas: `tools/make_textures.py` · Sons e músicas: `tools/make_sounds.py`

## Testado (sem tela, com o Godot 4.3)
- Os 4 mapas montam e o portal viaja entre eles.
- Jogo novo com UM clique em "Ir automático": do nível 1 ao 31 sozinho, 5 missões de história,
  incluindo a viagem para o deserto pelo portal, sem nenhuma parada.
- Com a história bloqueada por nível: diárias → semanais → mensais → caça, sem parar.
- Menu de administrador: itens, equipar, trocar de classe, nível, viagem.
- Limites das missões com datas simuladas (diárias, semanais na segunda-feira, mensais 30 por dia).
- XP 10x menor a partir do 31, bônus dos equipamentos, salvar/carregar.
Ainda não testado: jogar com teclado e mouse de verdade e o desempenho na sua placa de vídeo.

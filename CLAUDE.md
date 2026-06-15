# Great Fireball — notas pro Claude (core do projeto)

> Lido automaticamente todo início de sessão. Convenções duráveis do projeto.

## 🧙‍♀️ Personagem — IMPORTANTE
- **A Soph é uma MAGA. NUNCA "bruxa".** Preferência forte do Will: sempre
  direcionar a Sophia para *maga* / *sorceress* — **evitar qualquer associação
  com "bruxa"/"witch"** em código, comentários, diálogos, nomes de assets, arte
  e até nas conversas. O chapéu pontudo é **"chapéu de maga"** (não de bruxa).

## 🔵 Mana no cabelo — mecânica assinatura
- O **cabelo da Soph é o pool de mana**. Mana cheia = cabelo todo azul-mana.
- **Gasto: da RAIZ → PONTAS** (escurece de cima pra baixo). Vazio = todo escuro.
- **Regen: das PONTAS → RAIZ** (o azul "sobe" pelas pontas).
- **Meia mana = raiz escura + pontas azuis** — o visual "cabelo pintado"
  (homenagem ao cabelo da musa real). Referência base:
  `docs/concept_art/soph_base_ref.png`.
- ⚠️ A pixel-art atual faz o INVERSO (gasta das pontas → raiz): **inverter**
  quando regenerar os estados de mana (`gen_mana_states.py` / sprites).

## 🎨 Arte / sprites
- **HD via óculos é o caminho da Soph definitiva** (idle HD já no master;
  `USE_HD_SOPH = true` em `player.gd`). Pixel-art segue como fallback
  (`USE_HD_SOPH = false`) e padrão dos inimigos/cenário.
- Sprites são **procedurais** (`tools/art_director/soph_core.py` + `gen_all_frames.py`,
  e enemies/cenário em `scripts/autoload/sprite_setup.gd`) **+ overrides PNG**:
  o `SpriteSetup` carrega automaticamente um PNG cujo nome casa com a "chave"
  (ex.: `assets/sprites/player/soph_idle_0.png`) e substitui o procedural.
- **Rascunhos / concept art do Will** ficam em `docs/concept_art/`.
- Dinamismo de movimento da Soph (lean/stretch/squash) vive em
  `player.gd::_update_visuals`.

### 🛑 Rig PARADO — NÃO refatorar `player.gd` pra rig (decisão 2026-06-15)
- **NÃO** refatorar o `player.gd` pra ancorar animação em rig (Skeleton2D/
  Bone2D/cutout). O rig de T-pose frontal **não gera 3/4 nem lateral de ação**
  (bones 2D só transladam/rotacionam/escalam pixels existentes — não revelam o
  outro lado nem mudam silhueta). Está **engavetado** até entendermos o método
  do Hollow Knight.
- O caminho HD **é frame-by-frame** (`AnimatedSprite2D` + `SpriteFrames` em
  `_build_soph_frames_hd`) — que **já é** o método do HK. Manter assim.
- Frente ATIVA: **sheet única → fatiar frames** via
  `tools/art_director/gen_hd_sheet.py` (gera muitas poses numa geração só p/
  travar identidade, depois corta). Não conflitar com isso.
- Racional completo (HK + ferramentas de ancoragem): `docs/animacao_hk_notas.md`.

### ⚔️ Combate & armas (princípio HK — decisão 2026-06-15)
- **Arma só na AÇÃO.** Locomoção (idle/walk/run/dash/jump/fall/hurt) é **sem
  arma, mãos vazias** — silhueta limpa, menos drift, fatiamento trivial (foi o
  cajado que fazia ponte entre células). Refletido nos `POSE_SETS` do
  `gen_hd_sheet.py` (`WEAPON_SETS` controla quem mostra arma).
- **Ataque padrão = FÍSICO** (frente): iaido draw-slash — anticipação → **smear**
  (lâmina borrada, esconde o movimento rápido e é generoso p/ a geração) →
  corte limpo (1 frame de silhueta forte) → recuperação. Set `attack_phys`.
- **Cast = ESPECIAL caro, estilo Reigun do Yusuke** (3/4 → costas, **uma mão**
  ergue o cajado, outra escondida). Mais frames, mais dano, **custa muita mana**
  → o gasto **drena o cabelo** (a mecânica do cabelo-mana vira o medidor de
  custo). De costas esconde o rosto (menos drift). Set `cast_special`.
- **Smear frame** (quadro borrado) é a ferramenta-chave: esconde transições
  difíceis (a virada lado→costas do cast e a lâmina sendo sacada).

### 🪆 Paper doll — só REFERÊNCIA, não runtime (decisão 2026-06-15)
- Gerar base-corpo (bodysuit) + vestida com identidade travada **funciona** e é
  útil como model sheet / troca de skins (`gen_hd_sheet.py --set paperdoll`).
- **NÃO** usar como layering em tempo real: a robe **deforma por pose** (pano),
  logo cada frame de ação é desenhado inteiro — mesma razão do rig engavetado.

## 🌲 Mundo
- A "dungeon" (`dungeon_1`) é tematizada como **floresta** (céu de entardecer +
  grama + árvores + vaga-lumes) via `level_visuals.gd` (modo floresta quando o
  nível tem `DungeonManager`).
- Boss do slice: **Goblin Mutante** (arena trancada por avalanche de pedras).

## ✅ Validação (headless)
- Rodar com `$GODOT` (xvfb já configurado pelo hook de sessão).
- Probes úteis em `tools/`: `scene_smoke.gd`, `combat_probe.gd`, `boss_probe.gd`,
  `goblin_attack_probe.gd`, `archer_attack_probe.gd`.
- Após mudar PNGs, rodar `--editor --quit` uma vez (reimport) antes de testar.

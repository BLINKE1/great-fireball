# Great Fireball — notas pro Claude (core do projeto)

> Lido automaticamente todo início de sessão. Convenções duráveis do projeto.

## 🧙‍♀️ Personagem — IMPORTANTE
- **A Soph é uma MAGA. NUNCA "bruxa".** Preferência forte do Will: sempre
  direcionar a Sophia para *maga* / *sorceress* — **evitar qualquer associação
  com "bruxa"/"witch"** em código, comentários, diálogos, nomes de assets, arte
  e até nas conversas. O chapéu pontudo é **"chapéu de maga"** (não de bruxa).

## 🎨 Arte / sprites
- **Pixel-art é o padrão** (`USE_HD_SOPH = false` em `player.gd`). A HD é arte
  conceitual.
- Sprites são **procedurais** (`tools/art_director/soph_core.py` + `gen_all_frames.py`,
  e enemies/cenário em `scripts/autoload/sprite_setup.gd`) **+ overrides PNG**:
  o `SpriteSetup` carrega automaticamente um PNG cujo nome casa com a "chave"
  (ex.: `assets/sprites/player/soph_idle_0.png`) e substitui o procedural.
- **Rascunhos / concept art do Will** ficam em `docs/concept_art/`.
- Dinamismo de movimento da Soph (lean/stretch/squash) vive em
  `player.gd::_update_visuals`.

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

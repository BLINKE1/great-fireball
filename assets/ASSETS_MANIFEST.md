# Manifesto de Assets — Great Fireball

Este projeto gera **todos os sprites proceduralmente em código** (`scripts/autoload/sprite_setup.gd`)
como fallback. Qualquer arte autoral entra por **override automático**: basta colocar um PNG
com o nome exato da chave numa das pastas de busca, e ele substitui o procedural em todas as
cenas. Se o arquivo não existir, o procedural continua rodando — **nada quebra**.

## Como o override funciona

1. No boot, o `SpriteSetup` gera os sprites procedurais.
2. Depois, `_load_overrides()` procura, para cada chave, um arquivo `<chave>.png`.
3. Ordem de busca (primeiro match vence):
   - `assets/sprites/`
   - `assets/sprites/player/`
   - `assets/sprites/enemies/`
   - `assets/sprites/items/`
   - `assets/tilesets/`
   - `assets/ui/`
4. Se achar, usa o arquivo. Se não, mantém o procedural.

> No boot, o console imprime `[SpriteSetup] Authored art loaded for: ...` listando o que foi substituído.

## Regras para o asset-creator gerar arquivos compatíveis

- **Nome do arquivo = chave exata + `.png`** (ex.: `player_body.png`). Sem maiúsculas, sem espaços.
- **Fundo transparente** (alpha).
- **Mesma proporção** do tamanho procedural (a coluna "Tamanho proc." abaixo). Pode ser maior em
  resolução (ex.: 2x, 4x) desde que mantenha a proporção — o `Sprite2D` escala no jogo.
- **Pés/base na borda inferior** e centralizado horizontalmente, para alinhar no chão.
- Para pixel art, manter `Filter = Nearest` (já configurado nos nós das cenas).

## Tabela de chaves

### Personagem (pasta sugerida: `assets/sprites/player/`)
| Chave | Tamanho proc. | Descrição |
|-------|---------------|-----------|
| `player_body` | 32×64 | Corpo da Soph |
| `player_hair` | 32×20 | Cabelo azul (camada separada, sobre o corpo) |

### Inimigos (pasta sugerida: `assets/sprites/enemies/`)
| Chave | Tamanho proc. | Descrição |
|-------|---------------|-----------|
| `goblin` | 24×40 | Goblin comum |
| `goblin_leader` | 36×54 | Goblin líder |
| `goblin_archer` | 28×40 | Goblin arqueiro |
| `goblin_arrow` | 20×6 | Flecha do arqueiro |
| `fire_goblin_archer` | 28×40 | Goblin arqueiro de fogo |
| `fire_goblin_arrow` | 22×6 | Flecha flamejante |
| `golem` | 40×60 | Golem (QTE da torre) |
| `forest_ogre` | 52×64 | Ogro/boss mutante da floresta |
| `ogre_shockwave` | 28×12 | Onda de choque do ogro |

### Itens / objetos (pasta sugerida: `assets/sprites/items/`)
| Chave | Tamanho proc. | Descrição |
|-------|---------------|-----------|
| `chest` | 32×32 | Baú |
| `checkpoint_off` | 16×24 | Checkpoint desativado |
| `checkpoint_on` | 16×24 | Checkpoint ativado |
| `mana_orb` | 12×12 | Orbe de mana |
| `portal` | 32×48 | Portal |

### Projéteis / efeitos (pasta sugerida: `assets/sprites/`)
| Chave | Tamanho proc. | Descrição |
|-------|---------------|-----------|
| `missile` | 28×12 | Míssil básico |
| `magic_missile` | 28×12 | Míssil mágico (feitiço aprendido) |
| `missile_spread` | 28×12 | Míssil em leque |
| `missile_piercing` | 36×10 | Míssil perfurante |
| `missile_giant` | 56×24 | Míssil gigante |
| `missile_curved` | 24×14 | Míssil curvo |
| `sword_slash_arc` | 52×8 | Arco do golpe de espada |
| `light_tex` | radial | Textura de luz/glow |

### Tilesets / cenário (pasta sugerida: `assets/tilesets/`)
| Chave | Tamanho proc. | Descrição |
|-------|---------------|-----------|
| `floor_tile` | 32×32 | Piso |
| `platform_tile` | 32×16 | Plataforma |
| `wall_tile` | 16×32 | Parede |
| `bg_stone` | 32×32 | Pedra de fundo |
| `cave_far` | grande | Fundo de caverna (distante) |
| `cave_mid` | grande | Fundo de caverna (médio) |

## Animações (futuro)

Quando o asset-creator entregar **poses de animação** da Soph, o plano é migrar o `Sprite2D`
para `AnimatedSprite2D`. Poses prioritárias: `idle`, `walk`, `cast_missile`, `cast_heal`,
`air_hike`, `hurt`, `scared`, `awe`. Spritesheets vão para `assets/animations/`.

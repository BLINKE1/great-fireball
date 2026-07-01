# 🌲 Pipeline de Backgrounds / Ambientes (estilo John Avon)

> Como criar os cenários do jogo (a 1ª floresta e além). Mesmo espírito do
> pipeline de personagens: **gera arte (Pollinations) → vira override/asset →
> o jogo carrega**. Referência da 1ª floresta: **John Avon** (florestas MtG —
> troncos verticais, névoa verde, god-rays).

## Como o jogo desenha o cenário hoje (`scripts/world/level_visuals.gd`)
Níveis com `DungeonManager` = tema **floresta**. Camadas:
- **CaveBG** (CanvasLayer, layer -100): backdrop full-screen (antes gradiente,
  agora o **PNG pintado** se existir — `_load_backdrop`).
- **Árvores espalhadas** (`_scatter_trees`, chave `forest_tree`) no mundo.
- **Vaga-lumes** (partículas).
- ⚠️ O parallax de árvores (`forest_far`/`forest_mid`) está **desligado na
  floresta** (limite de câmera da dungeon) — a profundidade vem do backdrop.

## As camadas ideais (fundo → frente) = profundidade por parallax
| Camada | Asset | Geração | Parallax |
|---|---|---|---|
| 1. Céu/névoa/god-rays | `forest_backdrop.png` | Pollinations John Avon | lento/estático |
| 2. Árvores distantes | `forest_far` | silhuetas na névoa, tileável | lento |
| 3. Árvores médias | `forest_mid` | árvores + alpha | médio |
| 4. Árvore de frente | `forest_tree` | 1 árvore recortada (alpha) | rápido |
| 5. Chão/grama + vaga-lumes | procedural | — | mundo |

## Os 3 truques técnicos
1. **Tileável na horizontal** (camadas que rolam): emenda esquerda=direita via
   espelho ou blend de borda (na névoa some). O backdrop **estático** (v1) não
   precisa.
2. **Alpha nas camadas da frente**: flux não faz transparência. Truque: gerar
   **silhuetas escuras sobre névoa clara** → threshold vira máscara alpha fácil.
   (Mesma ideia do key-out do goblin.)
3. **Bake pra resolução do jogo** (640×360 / janela 1280×720). Backdrop pintado
   fica liso (atmosfera); os elementos de gameplay seguem pixel.

## Geração (Pollinations)
```bash
POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_pollinations.py \
  "atmospheric fantasy forest, John Avon Magic the Gathering forest style, tall \
vertical trunks in luminous misty green fog, golden god rays, deep emerald teal, \
painterly, no characters, no text, side-scroller backdrop, wide" \
  out.jpg 1216 704 <seed> flux
```
Depois: crop 16:9 → resize 1280×720 → `assets/sprites/backgrounds/forest_backdrop.png`.

## Estado
- ✅ **v1 (feito):** backdrop John Avon full-screen atrás da floresta
  (`forest_backdrop.png` + `_load_backdrop` no `level_visuals.gd`). Fallback pro
  gradiente se o PNG sumir.
- ✅ **v1.5 (feito): FOREGROUND estilo HK/Rayman.** Folhagem escura (silhueta →
  alpha) numa `ParallaxBackground` `layer=5` (frente do gameplay, atras da UI≥8),
  `motion_scale=1.35` (rola mais rapido = "perto da tela"), `motion_mirroring`
  pra tileia. Asset: `forest_foreground.png`. Ajuste fino: consts `FG_SCALE`/`FG_Y`
  no `level_visuals.gd`.
- ⏳ **v2:** árvore de frente John Avon com **alpha** (substitui a árvore pixel
  procedural) + mais camadas de parallax (far/mid) com profundidade real.
- ⏳ **v3:** variações (clareira, mais fechado, o arco de pedras do boss) e
  tileável pra scroll.

## Próximos ambientes (mesmo pipeline)
Torre (interior, cap.1), arena do boss (arco de pedras/avalanche), cavernas.
Cada um: gera backdrop no estilo-alvo → `*_backdrop.png` → `level_visuals`
escolhe por tema.

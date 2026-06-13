# Ecossistema Great Fireball

Mapa dos 3 repos relacionados ao **Great Fireball** e como eles se conectam.

---

## 1. `BLINKE1/great-fireball` (este repo, PUBLIC)

O jogo em si. 2D Metroidvania / run-and-gun com a **Soph** (maga) como
protagonista, em GDScript/Godot 4.

- Arte HD da Soph via **Pollinations kontext** img2img (o "óculos")
- Pixel-art procedural pros enemies/cenário
- Stages: dungeon_1 (forest theme), runner stage, sala de testes
- Sistema de mana com cabelo como pool, convokes (família/amigos),
  míssil mágico múltiplo, escudo, time stop, etc.

Pipeline de arte fica em `tools/art_director/`:
- `gen_pollinations.py` — text2img (free, modelo `flux`)
- `gen_hd_from_idle.py` — img2img com idle como âncora (modelo `kontext`, custo em pollen)

---

## 2. `BLINKE1/assets-creator` (PRIVATE)

Produto/SaaS standalone: web app que transforma **rascunho → asset de jogo**
pronto (sprite ou tileset). Pipeline:

```
[upload sketch] → [IA refina linhas] → [4 variações de estilo]
                              → [usuário escolhe] → [export PNG/sheet/tileset]
```

**Stack:**
- Backend: FastAPI + Replicate (ControlNet + SDXL) + rembg + Pillow
- Frontend: Next.js 14 + Tailwind + shadcn/ui
- Auth/DB: Supabase
- Storage: Cloudflare R2

**Status:** em desenvolvimento, MVP não shipou.

### Relação com o great-fireball

Era pensado pra ser **a ferramenta que constrói os assets** do jogo. Hoje,
com a integração direta do Pollinations `kontext` em `tools/art_director/`,
boa parte do pipeline "rascunho → asset" do MVP já está coberta sem
precisar de UI própria.

**Candidato a pausar/arquivar**, mas peças aproveitáveis:
- Integração `rembg` (remoção de fundo local, mais robusta que threshold)
- Uso de **tile ControlNet** pra seamless tiling de verdade
  (o Pollinations não faz bem — relevante quando atacarmos tilesets)
- Padrão FastAPI da pipeline (reusável em outros produtos)

Alternativa: redirecionar o assets-creator pra ser **uma UI em cima do
pipeline kontext+rembg+normalize** que já existe aqui, em vez de manter
a stack Replicate pesada.

---

## 3. `BLINKE1/great-fireball-teaser` (PUBLIC)

Concept Trailer / AMV pra hype do jogo. Mockup AI-gen sincronizado com
**"Golden" — HUNTR/X**, ~3:25 de duração.

Mistura cenas de anime + mockups de gameplay. Beats principais:

| Tempo | Beat |
|-------|------|
| 0:00 | Soph descendo do céu (anime), de costas numa colina |
| 1:04 | "po po po" sincroniza com missile spread (esfera dispara mísseis em 6 direções, gira, dispara mais 6) |
| 1:18 | Soph em rush + Boss dragão humanoide branco/dourado aterriza |
| 1:34 | Queda em slow motion (anime) |
| 1:42 | Brilho restaurador (anime) |

Tem storyboard cena-a-cena em `storyboard/storyboard.md` no repo.

**Status:** storyboard escrito, mockups não construídos.

### Relação com o great-fireball

O teaser **precisa da Soph final** (a arte HD definitiva que ainda está
sendo refinada aqui no `great-fireball`). Quando os assets HD estiverem
"tinindo" (regen via kontext completa, todas as anims consistentes em
bbox e direção), o teaser tem insumo pra começar.

O **Boss dragão branco/dourado** mencionado no storyboard ainda precisa
virar concept art — pode ser feito pelo mesmo pipeline kontext (anchored
em uma referência) quando saldo do Pollinations permitir.

---

## Resumo da conexão

```
        assets-creator                great-fireball                great-fireball-teaser
        (SaaS, opcional)              (JOGO)                        (AMV / hype)
              │                            │                                  │
              └─── constrói assets ───────►│                                  │
                                            │                                  │
                                            └────── arte final ───────────────►│
                                                                                
              (hoje: pipeline kontext em great-fireball
               cobre o que o assets-creator faria — então a
               seta esquerda virou um caminho mais direto)
```

Triângulo virou pipeline mais linear:
**Pollinations kontext + tools/art_director/ → great-fireball (arte) → teaser (hype)**

O assets-creator vira **reserva de técnicas** (rembg, tile ControlNet, FastAPI
pattern) pra quando precisarmos de algo que o pipeline atual não cobre — por
exemplo, tilesets seamless de verdade.

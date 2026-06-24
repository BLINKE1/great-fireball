# 🎮 Soph3D — Plano B: 3D ao vivo com câmera travada em 3/4

> **Quando isto importa:** se o método "**assar 3D → sprites 2D**" (Dead Cells)
> bater num muro intransponível na etapa de fatiar/pintar a sheet, este é o
> **escape hatch**: usar a **Soph 3D de verdade no jogo**, em tempo real, com a
> **câmera travada num ângulo 3/4 fixo**. Ela continua 3D, mas "lê" como 2D.
>
> **Status:** Plano B documentado. **NÃO** é a aposta principal (continua o
> Dead Cells / bake → 2D). Fica ancorado caso a gente precise pivotar.

## É técnica real? Sim — chama "2.5D / 3D fixed-camera"
Modelos 3D rodando ao vivo, câmera presa num ângulo → aparência de jogo 2D.
Jogos que já fizeram:
- **Diablo** (série inteira) — 3D real-time, câmera travada isométrica. O arquétipo.
- **Tunic**, **Death's Door** — 3D ao vivo, câmera fixa, leitura limpíssima.
- **Trine**, **Klonoa**, **Little Nightmares**, **INSIDE** — **3D num plano 2D**
  (plataforma/ação com câmera lateral/3-4 fixa). Grupo mais perto do nosso.
- Ironia: o **próprio Dead Cells é 3D** — só **assa** pra 2D. "Não assar" = exatamente este Plano B.

## Trade-offs (assar vs. 3D ao vivo)
| Critério | Assar → 2D (Plano A, Dead Cells) | 3D ao vivo, câmera travada (Plano B) |
|---|---|---|
| **Perf no celular** | ✅ baratíssimo (sprite) | ⚠️ mais caro (3D + shader em runtime) |
| **Look pintado** | ✅ dá pra pintar / ControlNet | ⚠️ tem que sair de **shader toon ao vivo** |
| **Pipeline** | ❌ fatiar sheet, gerenciar frames, ControlNet | ✅ **anim só toca**, sem sheet, sem ControlNet |
| **Consistência 3/4** | ✅ (por construção) | ✅ (de graça — é 3D mesmo) |
| **Drift entre frames** | ✅ zero | ✅ zero |

## Por que é viável pro nosso caso (mobile)
- Celular moderno aguenta **3D estilizado** (Genshin roda em telefone). Com arte
  enxuta (os ~16k tris que o Hunyuan já deu, poucas luzes, sem PBR pesado), roda.
- **O contorno preto HK (inverted-hull) que já protótipamos roda AO VIVO no
  Godot** (`grow` + `cull_front` + material preto). Então o look HK **não se
  perde** — mantém contorno + toon shader em tempo real.
- As animações **só tocam** (`AnimationPlayer`), sem pipeline de sheet.

## O que se PERDE (custo do pivot)
1. **Headroom de perf no celular** — 3D + shader custa mais que blit de sprite.
   Mitigável com LOD, poucas luzes, mesh leve.
2. **Riqueza do "pintado à mão"** — o look fica do **shader toon ao vivo**, não
   da pintura/ControlNet. Mais "cel-shaded limpo", menos "ilustração".

## Como seria no Godot (esboço)
- `Camera3D` **ortográfica**, travada no azimute 3/4 (≈ az=315, validado em
  `tools/rig3d/orient_probe.gd` / `walk_render.gd`), sem rotacionar com o player.
- Soph = cena do `soph_rigged.fbx` (ou rig melhor) com `AnimationPlayer`.
- Material **toon** + **inverted-hull outline** (mesmo da nuvem) p/ o look HK.
- Gameplay 2D no plano; o 3D é só apresentação. Inimigos/cenário podem seguir 2D
  (misto é comum e barato).

## Gatilho de decisão
Só puxar o Plano B **se** a etapa de assar (sheet/ControlNet/consistência de
pintura) se mostrar inviável depois de tentada de verdade. Até lá, **Plano A
(bake → 2D) segue sendo a aposta** — mantém o look pintado e a perf de sprite.

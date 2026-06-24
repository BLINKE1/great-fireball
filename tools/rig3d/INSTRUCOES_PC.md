# Soph3D — estado + próximos passos (pra instância do PC)

> Lido pela instância do **Claude no PC do Will** (que tem Blender + GPU). A nuvem
> não tem Blender; aqui está exatamente onde paramos e o que falta. Runbook
> técnico passo-a-passo segue em `README.md` (mesma pasta).

## 🏆 ATUALIZAÇÃO 2026-06-24 — PIPELINE VALIDADO PONTA-A-PONTA (Hunyuan 3D Studio)
> O fluxo abaixo (Tripo/manual) virou histórico: o **Tencent Hunyuan 3D Studio**
> (`3d.hunyuan.tencent.com/studio`) faz **tudo na nuvem, de graça**. Sequência que
> funcionou e está provada:
> 1. **`几何生成`** (geometria) modo **`上传多视图`** ← subir os 3 PNGs de
>    `docs/concept_art/multiview/soph_mv_{front,side,back}.png`. Identidade travada
>    (chapéu, **óculos**, robe, botas).
> 2. **`纹理绘制` → `图生纹理`** (textura por imagem): cabelo azul-mana + robe + pele.
> 3. **`低模拓扑`** (retopo, V1.5, médio, **`四边面`=QUADS**): 1.5M→**16.6k faces**.
>    ⚠️ não roda em asset pós-textura ("后置节点资产无法拓扑") → selecionar o nó da
>    GEOMETRIA antes de retopologizar.
> 4. **`绑骨蒙皮`** (auto-rig 1 clique): esqueleto **28 ossos estilo Mixamo**.
> 5. **`动画生成`**: só templates genéricos de combate (teste de deformação).
>
> **Deformação (testado no Blender via MCP):** **WALK/locomoção = limpa, zero fling.**
> ⚠️ Rig é só biped (sem ossos de cabelo/robe) → braço-acima-da-cabeça (combate +
> `cast_special` de costas) dá **fling** do pano/cabelo. Resolver depois: peso
> por-pose / ossos de saia / cloth sim. **Locomoção não precisa.**
>
> **Assets:** `tools/rig3d/in/soph_rigged.fbx` (rig, no git). Mesh vestido
> texturizado de 69MB → cache local `D:\Projetos\great-fireball-local-cache\soph3d\`
> (fora do git; re-baixável do histórico do Hunyuan).
>
> **Próximo:** anims de locomoção (Mixamo idle/walk/run no `soph_rigged.fbx`) →
> re-texturizar → render 3/4 → sprite sheet.

## 🚀 TL;DR — comece por aqui (passo a passo)

```bash
# 0) Pegar o estado mais novo
git checkout master && git pull origin master
# conferir que o set multiview chegou (3 PNGs, mesma escala):
ls docs/concept_art/multiview/soph_mv_front.png \
   docs/concept_art/multiview/soph_mv_side.png \
   docs/concept_art/multiview/soph_mv_back.png
```

1. **Mesh 3D (Hunyuan multiview).** Abra o HF Space `tencent/Hunyuan3D-2`
   (sem login chinês) → modo **multiview**. Suba:
   - slot **front** → `soph_mv_front.png`
   - slot **back**  → `soph_mv_back.png`
   - slot **left** (ou right) → `soph_mv_side.png`
   Gere **com textura** → baixe o **GLB** em `tools/rig3d/in/soph_dressed_mesh.glb`.

2. **(Opcional) Retopo/textura — Modddif.** Suba o GLB em `modddif.com`, otimize,
   reexporte. ⚠️ Confira no olho se a malha/UV saiu limpa; se piorar, pule e faça
   retopo manual no Blender depois. Não trave a cara da Soph nele sem olhar.

3. **Rig (Mixamo).** `mixamo.com` → **Upload Character** (o GLB) → marque queixo/
   pulsos/cotovelos/joelhos/virilha → **Idle** → **Download**: FBX, **With Skin**,
   30 fps → `tools/rig3d/in/soph_idle.fbx`. (Depois repita p/ Walk, Run.)

4. **Render 3/4 → PNGs.** Caminho recomendado = Godot (paridade c/ a nuvem):
   adaptar `turntable_godot.gd` p/ posar o `Skeleton3D` do FBX (trocar "girar
   pivô" por "tocar a animação"). Alternativa Blender:
   ```bash
   blender --background --python tools/rig3d/render_soph_3q.py -- \
     --fbx tools/rig3d/in/soph_idle.fbx --out tools/rig3d/out/idle \
     --res 512x768 --az 35 --el 12 --outline 0.02 --toon
   ```
   ⚠️ Antes ver os **gaps do `render_soph_3q.py`** (seção abaixo).

5. **Sprite sheet → Godot.**
   ```bash
   python tools/rig3d/pack_sheet.py --in tools/rig3d/out/idle --cols 8
   ```
   Importar como `SpriteFrames`/`AnimatedSprite2D` (caminho do `_build_soph_frames_hd`).

6. **Olhar e decidir:** "é a Soph, em 3/4, consistente?" → se sim, repete o passo
   4 p/ as outras ações. **Armas** entram como mesh separado preso ao osso da mão
   (toggle por ação). **Contorno HK** liga só no fim, por cena.

---


## A tese (1 parágrafo)
Modelar a Soph em **3D rigado** e **renderizar de uma câmera 3/4** pra sprite
sheets 2D (método Dead Cells / Guilty Gear Xrd). **Por que resolve o muro:** 3D
TEM o lado oculto de verdade → gira a câmera e sai 3/4 consistente em todo frame
→ **mata o drift** da pintura frame-a-frame. O jogo segue 2D (só PNGs no fim).

## O que a NUVEM já provou (não precisa refazer)
- ✅ **3/4 consistente** — `turntable_godot.gd` carrega o `.glb` no Godot headless
  (xvfb), gira a câmera e renderiza vários ângulos. **Mesma geometria girando =
  zero drift.** Validado nos ângulos 0/+35/-35/+90.
- ✅ **Fundo transparente (alpha)** mata a mescla com fundo no sprite sheet — e é
  o **alpha**, não o contorno, que resolve isso.
- ✅ **Contorno preto HK** é um **modificador de RENDER** (inverted-hull:
  `grow` + `cull_front` + material preto unshaded), **não toca no mesh**. Vira um
  **switch de estilo** no fim. Na Soph (quase toda preta) ele só lê na borda
  contra cenário e separando as pontas mana → valor = peso/leitura sobre fundo
  ocupado, não necessidade técnica. Liga/desliga por cena.

## Assets-chave (já no repo)
| arquivo | o que é |
|---|---|
| `docs/concept_art/multiview/soph_mv_{front,side,back}.png` | **SET MULTIVIEW oficial** (normalizado: mesma escala/baseline). **É o input do Hunyuan.** |
| `docs/concept_art/soph_tpose_robe.png` (+ `_side.png` / `_back.png`) | T-pose vestida por vista (front/side/back). A `multiview/` é a versão normalizada destas. |
| `docs/concept_art/soph_base_tpose.png` | T-pose só do bodysuit (corpo esguio "nu"). |
| `docs/concept_art/soph_robe_ref.png` | referência da robe (upload do Will). |
| `tools/rig3d/in/soph_mesh.glb` | mesh ATUAL = só o bodysuit (sem robe), estático. **Vai ser substituído** pelo mesh da T-pose vestida. |
| `tools/rig3d/turntable_godot.gd` | preview 3/4 no Godot (valida na nuvem; base do render de poses). |
| `tools/rig3d/render_soph_3q.py` | render 3/4 no Blender (FBX→PNG, toon+contorno). |
| `tools/art_director/gen_soph_robe_tpose.py` | gerador da T-pose vestida (Pollinations img2img). |

## PRÓXIMOS PASSOS no PC (em ordem)
1. **Mesh 3D MULTIVIEW** — usar o set normalizado em
   `docs/concept_art/multiview/` (`soph_mv_front.png` / `_side.png` / `_back.png`,
   mesma escala/baseline) num gerador **multiview**: **Tencent Hunyuan 3D**
   (`3d.hunyuan.tencent.com` ou o HF Space `tencent/Hunyuan3D-2` — pula login
   chinês). Multiview > single-image (Tripo): mata o chute do lado oculto e
   segura a identidade. Salvar em `tools/rig3d/in/soph_dressed_mesh.glb`.
   > Fluxo de referência (vídeo Stefan 3D AI): imagens → **Hunyuan multiview** →
   > montar peças no Blender → **Modddif** (retopo/textura por IA, `modddif.com`)
   > → **Mixamo** (rig). Modddif é o elo menos provado: conferir a retopo/textura
   > antes de confiar; se decepcionar, retopo manual no Blender.
2. **Auto-rig + animação no Mixamo** — subir o GLB, marcar juntas, baixar
   **Idle** (depois Walk/Run) em FBX → `tools/rig3d/in/soph_idle.fbx`.
3. **Render 3/4** — duas vias:
   - (a) **Blender**: `render_soph_3q.py` (ver gaps abaixo antes).
   - (b) **Godot** (recomendado p/ paridade com a nuvem): adaptar
     `turntable_godot.gd` — trocar "girar pivô" por **posar o Skeleton3D** do FBX
     e renderizar os frames da ação. Mesmo loop, alpha transparente, contorno HK
     como toggle.
4. **Sprite sheet** — `pack_sheet.py --in out/idle --cols 8` → importar como
   `SpriteFrames`/`AnimatedSprite2D` (caminho do `_build_soph_frames_hd`).
5. **Armas SEPARADAS** — espada/cajado são **mesh próprio preso ao osso da mão**
   (bone socket), **toggle de visibilidade por ação** (arma só na ação — decisão
   HK). Nunca fundir na malha do corpo. Troca de arma sem re-rigar.
6. **Contorno HK** — ligar só no fim, decidir no olho por cena.

## ⚠️ Gaps conhecidos no `render_soph_3q.py` (corrigir antes de confiar)
- `--toon` **não é toon de verdade**: só zera specular/crava roughness. Falta um
  `ColorRamp` (ValToRGB) de 2-3 degraus no diffuse pra cel-shade real.
- **Armadilha de frame-range**: FBX sem `action` cai no default 1..250 → 250 PNGs
  idênticos. Guardar contra isso.
- Ordem de engine difere do `_smoke.py` (cosmético).

## ⚠️ Pontos sensíveis
- **Robe = pano que deforma** (saia longa). No walk/run ela amassa/balança — é o
  velho ponto do rig de pano. O **bodysuit por baixo** é o que riga limpo; a robe
  pode precisar de bones extras de saia (ou physics) ou aceitar rigidez.
- **Topologia do Tripo** é triangulada/orgânica → pode pedir **retopo** pra
  deformar bem em cotovelo/joelho/axila.

## Regras do projeto (não esquecer)
- A Soph é **MAGA / sorceress** — **nunca "bruxa"/"witch"**. Chapéu de **maga**.
- Cabelo = pool de **mana** (raiz→pontas no gasto). Pontas azul-mana já na base.

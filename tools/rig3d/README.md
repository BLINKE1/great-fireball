# Soph 3D → sprites 2D (3/4) — runbook do de-risk

> **Ideia (Will, 2026-06-22):** modelar a Soph em **3D rigado**, animar com mocap,
> e **renderizar de uma câmera 3/4** pra sprite sheets 2D. O jogo continua 2D
> (só PNGs no fim, roda no celular). É o método do **Dead Cells** / **Guilty
> Gear Xrd** / **Donkey Kong Country**.
>
> **Por que resolve o muro:** o cutout 2D não inventa o lado oculto nem faz
> foreshortening → 3/4 e walk/run nunca saíam. **3D TEM o lado oculto de
> verdade** → gira a câmera e sai 3/4 perfeito, consistente em todo frame
> (mata o *drift* da pintura frame-a-frame, que é a dor #1).
>
> **Este runbook = experimento de DE-RISK.** Prova o conceito num dia, não num
> mês. Se passar ("isso é a Soph, em 3/4, consistente?"), vira o pipeline
> definitivo da personagem.

## Por que parte é web e parte é PC
- **Mesh (image-to-3D)** e **rig+anim (Mixamo)** → **web** (a GPU aqui é Intel
  Iris Xe integrada; gerador 3D local tipo Hunyuan3D precisa de NVIDIA/CUDA).
- **Render 3/4 cel-shaded → sprites** → **Blender local** (scripts aqui).

---

## Passo 1 — Mesh 3D a partir da arte (web, ~10 min)
Entrada: **`docs/concept_art/soph_base_tpose.png`** (T-pose limpa = melhor pro rig).

Ferramenta (free tier, escolha uma):
- **Tripo3D** — https://www.tripo3d.ai (forte em personagem; exporta GLB/FBX/OBJ)
- **Meshy** — https://www.meshy.ai (Image→3D)
- **Rodin / Hyper3D** — https://hyper3d.ai

Config recomendada no gerador:
- modo **Image to 3D**, suba a T-pose;
- ligue **symmetry** / **T-pose** se houver;
- gere **com textura** (PBR/“texture”);
- baixe como **GLB** (preferido) ou **FBX**.

Salve em `tools/rig3d/in/soph_mesh.glb` (crie a pasta `in/`).
> ⚠️ Primeira passada é a **base bodysuit** (cabelo-mana já dá identidade).
> Chapéu/robe entram numa 2ª passada (mesh separada ou modelada).

## Passo 2 — Auto-rig + animação (Mixamo, web, ~10 min)
1. https://www.mixamo.com (conta Adobe grátis).
2. **Upload Character** → suba o GLB/FBX do passo 1.
3. Auto-rigger: marque queixo, pulsos, cotovelos, joelhos, virilha → **Next**.
4. Escolha uma animação: comece com **Idle** (depois **Walking**, **Running**).
5. **Download**: Format **FBX**, Skin **With Skin**, **30 fps**, keyframe reduction
   none. Salve em `tools/rig3d/in/soph_idle.fbx`.
> Já temos mocaps em `assets/mixamo/*.fbx` — mas o jeito simples do de-risk é
> pegar o Idle já aplicado na Soph aqui no Mixamo.

## Passo 3 — Render 3/4 cel-shaded + contorno (Blender, script)
Com o Blender instalado (winget `BlenderFoundation.Blender`):

```bash
# render do idle: FBX -> sequencia de PNG 3/4 com toon + contorno preto
blender --background --python tools/rig3d/render_soph_3q.py -- \
  --fbx tools/rig3d/in/soph_idle.fbx \
  --out tools/rig3d/out/idle \
  --res 512x768 --az 35 --el 12 --outline 0.02
```
Saída: `tools/rig3d/out/idle/f0001.png ...` (fundo transparente, câmera 3/4).
Ajuste fino por olho: `--az` (azimute do 3/4), `--el` (elevação), `--ortho`
(zoom), `--outline` (espessura do contorno), `--toon` (liga rampa cel-shade).

## Passo 4 — Sprite sheet + Godot
```bash
# empacota os frames numa folha (strip horizontal por padrao)
python tools/rig3d/pack_sheet.py --in tools/rig3d/out/idle --cols 8
#   -> tools/rig3d/out/idle_sheet.png
```
No Godot: importar como `SpriteFrames`/`AnimatedSprite2D` (mesmo caminho do
`_build_soph_frames_hd` no `player.gd`). Daí a gente OLHA: **é a Soph? em 3/4?
consistente entre frames?** → decide se vira o pipeline oficial.

---

## Mapa dos arquivos
- `render_soph_3q.py` — Blender: importa FBX, câmera 3/4 ortho, toon + contorno
  (inverted-hull), filme transparente, renderiza a animação pra PNG.
- `pack_sheet.py` — PIL: frames → sprite sheet/strip.
- `in/` — meshes e FBX baixados (web). `out/` — frames e sheets.

## Honestidade (o custo real)
- O **gargalo é o mesh 3D** com identidade + topologia boa. Image-to-3D encurta,
  mas pede limpeza/retopo pra animar bem.
- **Cel-shade pra bater no look pintado** pede ajuste (toon + outline + luz
  flat). É o que a Xrd fez — e a gente já quer o contorno preto (decisão HK).
- Se o de-risk convencer, o resto (mais animações, mais ângulos) é repetir o
  passo 3 com outros FBX. Sem drift, por construção.

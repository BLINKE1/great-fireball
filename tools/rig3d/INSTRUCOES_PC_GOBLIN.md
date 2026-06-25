# Goblin3D — runbook pro PC (inimigo basal)

> Lido pela instância do **Claude no PC do Will** (Blender + GPU). A nuvem não
> tem Blender. Mesmo pipeline da Soph, **mais simples**: o goblin não tem robe
> longa, nem cabelo-mana, nem rosto frágil (a cara dele já passa no pixel-bake
> Dead Cells). Runbook técnico geral da Soph: `INSTRUCOES_PC.md` + `README.md`.

## 🎯 O que já está pronto (na nuvem, no git)
Set **multiview A-pose ABERTA** (vão da axila visível → braço não funde no mesh,
rig limpo). Identidade travada: goblin MTG estilo **prospector / Wayne Reynolds**
— pele oliva-amarelada, espinhos ósseos nos ombros/espinha, orelhonas, bocarra
dentuça, garras, túnica esfarrapada + cinto. **Mãos vazias** (arma vem depois,
mesh separado).

| arquivo | o que é |
|---|---|
| `docs/concept_art/goblin/goblin_front.png` | **FRENTE** A-pose aberta (input multiview) |
| `docs/concept_art/goblin/goblin_side.png` | **LADO** (perfil direito) |
| `docs/concept_art/goblin/goblin_back.png` | **COSTAS** (espinha óssea visível) |
| `docs/concept_art/goblin/goblin_base_ref.{jpg,png}` | concept 3/4 original (A, escolha do Will) |
| `tools/art_director/gen_goblin_concept.py` | gerador do concept (Pollinations) |
| `tools/art_director/gen_goblin_multiview.py` | gerador das 3 vistas (img2img, flag `--anchor`) |

## 🚀 TL;DR — comece por aqui

```bash
git checkout master && git pull origin master   # ou o branch atual
ls docs/concept_art/goblin/goblin_front.png \
   docs/concept_art/goblin/goblin_side.png \
   docs/concept_art/goblin/goblin_back.png
```

1. **Mesh 3D (Hunyuan 3D Studio — fluxo provado na Soph, grátis na nuvem).**
   `3d.hunyuan.tencent.com/studio`:
   - **`几何生成`** (geometria) → modo **`上传多视图`** (upload multiview):
     - **front** → `goblin_front.png`
     - **back**  → `goblin_back.png`
     - **left/right** → `goblin_side.png`
   - **`纹理绘制` → `图生纹理`** (textura por imagem): pele oliva, túnica, garras.
   - **`低模拓扑`** (retopo, V1.5, **`四边面`=QUADS**). ⚠️ selecionar o nó da
     **GEOMETRIA** antes (não roda em asset pós-textura).
   - **`绑骨蒙皮`** (auto-rig 1 clique): esqueleto ~28 ossos estilo Mixamo.
   - Baixar **GLB texturizado+rigado** → `tools/rig3d/in/goblin_rigged.glb`.
   > Alternativa: HF Space `tencent/Hunyuan3D-2` (pula login chinês) ou Tripo.
   > Multiview > single-image: mata o chute do lado oculto.

2. **(Se o Hunyuan não rigar bem) Rig no Mixamo.** `mixamo.com` → Upload Character
   (GLB) → marcar queixo/pulsos/cotovelos/joelhos/virilha → baixar **Idle** (depois
   Walk) em **FBX, With Skin, 30fps** → `tools/rig3d/in/goblin_idle.fbx`.
   > A A-pose aberta foi feita pra isso: Mixamo aceita A-pose, e o vão da axila
   > dá separação limpa de ombro.

3. **Entregar o rigado pra NUVEM.** Pushar `tools/rig3d/in/goblin_rigged.glb`
   (ou `goblin_idle.fbx`). A nuvem já tem o motor pronto:
   - **retarget por DESVIO** (Mixamo→Mixamo, fiel, em pé) — mesmo método dos
     `render_idle_textured.gd` / `render_walk_textured.gd` da Soph.
   - **render 3/4** (AZ=315, EL=7, enquadre pelos ossos).
   - **pixel-bake Dead Cells** (`pixel_bake.py --mode pixel --h 300 --colors 48`).
   - **sheet** → `SpriteFrames` no Godot.
   > Pra rodar igual à Soph, dá pra clonar `render_idle_textured.gd` trocando o
   > GLB de entrada por `goblin_rigged.glb` (e os FBX de anim do Mixamo).

4. **Plugar no jogo.** Hoje o goblin é procedural (`sprite_setup.gd::_gen_goblin`,
   24×40, "arte primitiva"). O override por PNG já existe: o `SpriteSetup` carrega
   automaticamente um PNG cujo nome casa com a chave (`goblin`). Soltar o sheet
   bakeado lá substitui o procedural sem mexer em código de gameplay.

## ⚔️ Armas (regra do projeto — igual HK/Soph)
- Goblin base = **mãos vazias** (locomoção limpa, fatiamento trivial).
- Adaga/clava/tocha = **mesh separado preso ao osso da mão** (bone socket),
  **toggle por ação**. Nunca fundir na malha. Resolve o grip torto na origem
  (foi por isso que a base saiu sem arma).

## 🟢 Mais fácil que a Soph (não precisa penar aqui)
- **Sem robe longa** → sem cloth sim. Túnica curta + tiras = rígido resolve.
  O dream rig (cloth) é problema da Soph, **não do goblin basal**.
- **Sem cabelo-mana** → sem spring bones. A crista é rígida.
- **Rosto perdoado** pelo pixel-bake Dead Cells → não precisa consertar a cara.

## 🔮 Depois (variantes — reusar o mesmo set)
O `gen_goblin_multiview.py` aceita `--anchor`: dá pra derivar **grunt / archer /
elite / o mutante roxo (boss)** mudando cor/escala/adereços a partir da frente
canônica, mantendo a família coerente. (Já existem no procedural:
`goblin_archer`, `goblin_leader`, `goblin_mutant`.)

## Regras do projeto (não esquecer)
- A Soph é **MAGA / sorceress** — nunca "bruxa". (Não afeta o goblin, mas vale
  pra qualquer arte da sessão.)
- Pixel-bake = **Dead Cells 1080p** (`docs/design/visual_style.md`): ~300px,
  48 cores, **sem contorno preto** no goblin (decisão da Soph; revisar no olho).

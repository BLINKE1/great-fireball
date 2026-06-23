# Soph3D — estado + próximos passos (pra instância do PC)

> Lido pela instância do **Claude no PC do Will** (que tem Blender + GPU). A nuvem
> não tem Blender; aqui está exatamente onde paramos e o que falta. Runbook
> técnico passo-a-passo segue em `README.md` (mesma pasta).

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
| `docs/concept_art/soph_tpose_robe.png` | **NOVA base oficial**: T-pose esguia VESTIDA (maga: robe roxo-escuro, chapéu de maga, óculos, pontas mana, botas). **É daqui que sai o mesh definitivo.** |
| `docs/concept_art/soph_base_tpose.png` | T-pose só do bodysuit (corpo esguio "nu"). |
| `docs/concept_art/soph_robe_ref.png` | referência da robe (upload do Will). |
| `tools/rig3d/in/soph_mesh.glb` | mesh ATUAL = só o bodysuit (sem robe), estático. **Vai ser substituído** pelo mesh da T-pose vestida. |
| `tools/rig3d/turntable_godot.gd` | preview 3/4 no Godot (valida na nuvem; base do render de poses). |
| `tools/rig3d/render_soph_3q.py` | render 3/4 no Blender (FBX→PNG, toon+contorno). |
| `tools/art_director/gen_soph_robe_tpose.py` | gerador da T-pose vestida (Pollinations img2img). |

## PRÓXIMOS PASSOS no PC (em ordem)
1. **Mesh 3D da T-pose VESTIDA** — subir `docs/concept_art/soph_tpose_robe.png`
   no Tripo3D/Meshy (Image→3D, com textura) → salvar em
   `tools/rig3d/in/soph_dressed_mesh.glb`. (A `soph_mesh.glb` atual é só o
   bodysuit — serve de fallback/corpo, mas o alvo agora é a vestida.)
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

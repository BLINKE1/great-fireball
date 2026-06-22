# Rig "pesado" da Soph — runbook pro PC

> Pipeline de **auto-rig + mocap** que NÃO roda no container da nuvem (precisa
> de libs pesadas: MediaPipe, OpenCV, NumPy, e **Blender** pro mocap). Rode no
> teu PC. As peças já cortadas e o `soph_rig.tscn` gerado estão commitados —
> isto aqui é pra **regenerar/evoluir**.

## O que essa solução faz (a forma "inteligente")
Em vez do meu PoC bruto (`player_rig_v2.gd` = 2 pedaços + seno na mão), aqui:
1. **MediaPipe** detecta as 33 juntas no personagem → posiciona os ossos nas
   juntas REAIS (ombro/cotovelo/joelho), não no olho.
2. **Corte por junta** → peças limpas (braços/pernas sup+inf, tronco, cabeça).
3. **Mocap do Mixamo** (idle/walk/run/cast/slash/hurt `.fbx`) → ângulos de osso
   → o rig é dirigido por **captura real**, não por seno.
4. **Skeleton2D + Bone2D** montado automaticamente no `.tscn`.
5. (opcional) **baka** poses pra PNG 100% consistente.

## Dependências (PC)
```bash
pip install -r tools/rig/requirements.txt   # mediapipe, opencv-python, numpy, pillow
# Blender (pro mocap): instalar separado — https://www.blender.org/download/
#   Linux/Mac: 'blender' no PATH | Windows: ajuste o caminho do blender.exe
```

## Pipeline — ordem de execução
```bash
# 1) Keypoints + máscara (entrada: docs/concept_art/soph_base_tpose.png)
python tools/rig/extract_keypoints.py
#    -> assets/rig/soph_tpose/{keypoints.json, mask.png, tpose_clean.png}

# 2) Corta a T-pose em peças nas juntas
python tools/rig/cut_parts.py
#    -> assets/rig/soph_tpose/parts/*.png + parts.json

# 3) MOCAP: Blender lê os FBX e exporta posições 3D dos ossos
blender --background --python tools/rig/parse_mixamo.py
#    -> assets/mixamo/bones_world.json

# 4) Projeta o mocap pro 2D (gera o módulo de poses)
python tools/rig/map_to_2d.py
#    -> tools/rig/poses_from_mixamo.py  (ALL_POSES)

# 5) Monta a cena do rig (Skeleton2D + Bone2D + Sprite2D por parte)
python tools/rig/build_rig_scene.py
#    -> scenes/characters/soph_rig.tscn

# 6) (opcional) Baka poses do rig pra PNG (substitui soph_hd_*.png)
python tools/rig/bake_frames.py --all --apply
```

## O upgrade "smart" de verdade: MALHA DEFORMÁVEL
O `build_rig_scene.py` hoje prende **Sprite2D rígidos** por osso (pedaços que
giram/transladam → seams nas dobras). O salto de qualidade (estilo Spine/
Live2D), **nativo no Godot**, é trocar por **deformação por malha**:

- Cada parte vira **`Polygon2D`** com `internal_vertex_count` + **`bones`/pesos**
  apontando pro `Skeleton2D`. Aí a robe/cabelo **dobram** suave, sem seam.
- No editor: **Polygon2D → UV → Bones** (pintar pesos por vértice).
- **Secundário com mola** no cabelo/capa (cadeia de bones + verlet/spring no
  `_process`) = follow-through, vida.
- Animar idle/lean/cast/hurt via **AnimationPlayer** (editável) ou pelas
  `ALL_POSES` do mocap.

Plano: estender `build_rig_scene.py` p/ emitir `Polygon2D` + pesos (ou montar
no editor uma vez e salvar como template).

## ⚠️ Honestidade (o limite que NÃO some)
Toda essa infra foi feita no **T-pose FRONTAL** (`soph_base_tpose.png`):
- **Ótima** pra idle/cast/gestos **de frente** (no plano) — aí mocap + malha
  brilham.
- **NÃO resolve 3/4 lateral nem walk/run** convincente: 2D não revela o lado
  oculto nem faz foreshortening; o mocap é 3D, projetar num cutout chato não
  conserta a oclusão das pernas. **Locomoção segue frame-by-frame** (pipeline
  de pintura / âncora dupla). É o **híbrido** que validamos.
- Pra um rig **3/4**, rode o mesmo pipeline numa referência 3/4 (não a T-pose
  frontal) — funciona pro mesmo conjunto (idle/gesto), com o mesmo teto.

## Mapa dos arquivos
- `tools/rig/extract_keypoints.py` · `cut_parts.py` · `parse_mixamo.py` (Blender)
  · `map_to_2d.py` · `build_rig_scene.py` · `bake_frames.py`
- `assets/rig/soph_tpose/parts/` — peças já cortadas (frontal)
- `assets/mixamo/*.fbx` — mocap (idle/walk/run/jump/cast/slash/hurt)
- `scenes/characters/soph_rig.tscn` — rig gerado (frontal, Sprite2D rígidos)
- `scripts/player/player_rig.gd` — driver do rig frontal (antigo)
- `scripts/player/player_rig_v2.gd` — PoC leve 3/4 (procedural, idle) — roda na nuvem

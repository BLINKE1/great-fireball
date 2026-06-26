# 🎨 Estilo Visual — Soph (decisão Will, 2026-06-25)

> Decisão de identidade visual do Great Fireball, fechada após o teste de bake
> de 1 frame (T-pose texturizada).

## DECISÃO: Dead Cells, 1080p
- **Estilo:** **pixel-art baked** (3D texturizado → render → pixel-bake
  determinístico), saída **HD 1080p crisp** (pixels nítidos, afiados). NÃO é o
  liso de Hollow Knight — é o **pixel chunky** do Dead Cells.
- **Resolução do jogo:** subir de `640×360` pra **1080p** (1920×1080 ou
  1280×720). Sprite da Soph bakeado em **~300px** de altura, exibido crisp.
- **Bake:** `pixel_bake.py --mode pixel --h 300 --colors 48` (sem contorno preto).

## Por que Dead Cells (e não HK liso)
- ✅ **Perdoa o rosto fraco** do mesh do Hunyuan (o pixel borra os defeitos de
  olho/óculos que o HD liso revelava). **Não precisamos consertar o rosto agora.**
- ✅ É o método que **já validamos** (o "320px" que o Will amou puxa pra cá).
- ✅ Cores fiéis sem contorno (botas marrons, cabelo mana, barra roxa).
- HK liso ficaria mais premium, mas **exigiria refazer o rosto** do mesh.

## Pipeline (Plano A, confirmado)
```
3D texturizado + rigado (juntar no Blender/Mixamo, lado PC)
   └─ retarget v2 (mocap Mixamo) ou pose procedural  ──►  frames 3D coloridos
         └─ pixel_bake.py (Dead Cells: ~300px, 48 cores, sem contorno)  ──►  sprites 2D
               └─ pack_sheet  ──►  SpriteFrames no Godot (1080p)
```

## Alvo travado
`tools/rig3d/out/textured/_target_deadcells.png` — frente + 3/4 no look final.

## Pendências
- **Juntar textura + rig** num arquivo (lado PC: Mixamo decimado ou Blender
  weight-transfer) → destrava assar MOVIMENTO (hoje só temos T-pose estática).
- **Subir a resolução do jogo** (`project.godot`: 640×360 → 1080p) quando for
  plugar os sprites.
- (Opcional/futuro) melhorar o **rosto** do mesh se um dia migrar pro HK liso.

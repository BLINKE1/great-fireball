"""Auto-pin map pro dream rig — classifica verts em (rigido / corpo / cabelo / drape)
usando bone+distancia+geometria, sem precisar pintar a mao.

Por que isto existe:
  O mesh do Hunyuan vem 1 blob de 154k verts, 1 material, sem grupos semanticos.
  Pra rodar cloth sim no dream rig FREE, precisamos saber o que e rigido (face,
  maos) vs drape (robe, manga, cabelo). Em vez de pintar a mao no Blender, este
  script aplica heuristica + Mixamo weights e cospe:
    1) Vertex Group "cloth_pin" (0..1, vai direto no Pin Group do cloth modifier)
    2) Vertex Color "pin_preview" (heatmap colorido pra olho conferir)
    3) 4 PNGs (front/back/side/3q) com a Soph pintada
    4) .blend salvo (NAO toca soph_rig_wip.blend — arquivo separado)
    5) JSON com stats por categoria

Como rodar:
  blender --background --python tools/rig3d/auto_pin_map.py

Saidas:
  tools/rig3d/out/dream_rig/auto_pin_{front,back,side,3q}.png
  tools/rig3d/out/dream_rig/soph_auto_pin.blend
  tools/rig3d/out/dream_rig/auto_pin_stats.json

Tuning depois de ver os PNGs:
  - Cabelo virou rigido por engano? -> aumenta R_HAIR (raio do cranio)
  - Manga virou rigida por engano? -> diminui R_BODY (raio do corpo)
  - Face virou floppy? -> aumenta R_FACE (raio frontal)
  Tudo no bloco THRESHOLDS abaixo.
"""

import bpy, bmesh, os, json, math
import mathutils as mu
import numpy as np


# ------------------------------------------------------------------ PATHS
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN_GLB = os.path.join(REPO, "tools", "rig3d", "in", "soph_textured_rigged.glb")
OUT_DIR = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig")
os.makedirs(OUT_DIR, exist_ok=True)

# ------------------------------------------------------------------ THRESHOLDS (tunaveis)
# Distancia do vert ate o head do bone com maior peso. Vert "colado" no bone = corpo.
# Vert afastado = envelope (robe/manga/cabelo).
R_FACE = 0.10   # raio do cranio (face/cabeca rigida). Aumenta se cabelo virar rigido
R_BODY = 0.10   # raio do corpo (torso/perna rigida). Diminui se manga virar rigida
R_ARM  = 0.04   # raio do braco/antebraco (skin colado vs manga)

# Pin values (1.0 = rigido, 0.0 = totalmente floppy)
PIN_RIGID  = 1.0   # face, maos, pes, cranio
PIN_BODY   = 0.9   # torso/braco/perna core
PIN_HAIR   = 0.6   # cabelo (jiggle leve) — era 0.4, subi pq pano desabava
PIN_DRAPE  = 0.7   # robe/manga/capa (cai com gravidade) — era 0.2, robe virava gel

# Renderizacao
RES_W, RES_H = 512, 768
CAM_DIST = 2.6      # distancia da camera ao centro
EL_DEG = 8.0        # elevacao da camera


# ------------------------------------------------------------------ HELPERS
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def pick_eevee():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            return eng
        except Exception:
            pass
    return None


def import_glb():
    bpy.ops.import_scene.gltf(filepath=IN_GLB)
    # Pega o MAIOR mesh (mais verts). Necessario porque addons (BlenderMCP) podem
    # injetar uma Icosphere de 42 verts no startup que aparece antes do mesh real.
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    mesh = max(meshes, key=lambda o: len(o.data.vertices))
    arm  = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    return mesh, arm


def bone_world_head(arm_obj, bone_name):
    b = arm_obj.data.bones.get(bone_name)
    if b is None:
        return None
    return arm_obj.matrix_world @ b.head_local


def classify_verts(mesh_obj, arm_obj):
    """Retorna lista de tuplas (pin_value, category) por vertex."""
    me = mesh_obj.data
    n = len(me.vertices)

    # Indexar bones por nome
    bone_heads = {b.name: bone_world_head(arm_obj, b.name) for b in arm_obj.data.bones}

    # Indices de vertex groups (mapeia idx->nome de bone)
    vg_index_to_bone = {vg.index: vg.name for vg in mesh_obj.vertex_groups}

    # Buckets de categorias (pra contar)
    cats = {"FACE": 0, "CRANIO": 0, "CABELO": 0, "MAO": 0, "PE": 0,
            "CORPO": 0, "ROBE_MANGA": 0, "OUTRO": 0}

    pins = np.zeros(n, dtype=np.float32)
    cat_array = np.empty(n, dtype=object)

    mw = mesh_obj.matrix_world

    for vi, v in enumerate(me.vertices):
        # Posicao world
        wp = mw @ v.co

        # Bone com maior peso
        best_bone = None
        best_w = -1.0
        for g in v.groups:
            if g.weight > best_w:
                best_w = g.weight
                best_bone = vg_index_to_bone.get(g.group)
        if best_bone is None:
            pins[vi] = PIN_DRAPE
            cat_array[vi] = "OUTRO"
            cats["OUTRO"] += 1
            continue

        bone_head = bone_heads.get(best_bone)
        dist = (wp - bone_head).length if bone_head is not None else 9.99

        # CLASSIFICACAO POR REGRAS
        # 1) Maos e dedos -> rigido total (Mixamo nomeia explicito)
        if "Hand" in best_bone or "Finger" in best_bone or "Thumb" in best_bone or "Index" in best_bone:
            pins[vi] = PIN_RIGID; cat_array[vi] = "MAO"; cats["MAO"] += 1; continue

        # 2) Pes -> rigido
        if "Foot" in best_bone or "Toe" in best_bone:
            pins[vi] = PIN_RIGID; cat_array[vi] = "PE"; cats["PE"] += 1; continue

        # 3) Head bone -> face / cranio / cabelo (decide por distancia + Y)
        if "Head" in best_bone or "Neck" in best_bone:
            if dist > R_FACE:
                # Longe do cranio = cabelo
                pins[vi] = PIN_HAIR; cat_array[vi] = "CABELO"; cats["CABELO"] += 1; continue
            else:
                # Perto do cranio: face (Y frontal) ou cranio (Y traseiro)
                # Lembrete: BBox Y foi [-0.24, 0.19], frontal = Y negativo
                if wp.y < -0.02:
                    pins[vi] = PIN_RIGID; cat_array[vi] = "FACE"; cats["FACE"] += 1
                else:
                    pins[vi] = PIN_RIGID; cat_array[vi] = "CRANIO"; cats["CRANIO"] += 1
                continue

        # 4) Bracos (Arm/ForeArm/Shoulder) -> skin colado = corpo. Longe = manga
        if "Arm" in best_bone or "Shoulder" in best_bone:
            if dist > R_ARM:
                pins[vi] = PIN_DRAPE; cat_array[vi] = "ROBE_MANGA"; cats["ROBE_MANGA"] += 1
            else:
                pins[vi] = PIN_BODY; cat_array[vi] = "CORPO"; cats["CORPO"] += 1
            continue

        # 5) Torso/quadril/pernas: perto = corpo, longe = robe/saia
        if any(k in best_bone for k in ("Spine", "Hips", "UpLeg", "Leg")):
            if dist > R_BODY:
                pins[vi] = PIN_DRAPE; cat_array[vi] = "ROBE_MANGA"; cats["ROBE_MANGA"] += 1
            else:
                pins[vi] = PIN_BODY; cat_array[vi] = "CORPO"; cats["CORPO"] += 1
            continue

        # Default
        pins[vi] = PIN_BODY; cat_array[vi] = "OUTRO"; cats["OUTRO"] += 1

    return pins, cat_array, cats


def write_vertex_group(mesh_obj, pins):
    """Grava pins[0..1] no vertex group 'cloth_pin' (Pin Group do cloth modifier)."""
    name = "cloth_pin"
    if name in mesh_obj.vertex_groups:
        mesh_obj.vertex_groups.remove(mesh_obj.vertex_groups[name])
    vg = mesh_obj.vertex_groups.new(name=name)
    for vi, w in enumerate(pins):
        vg.add([vi], float(w), 'REPLACE')
    return vg


def write_preview_colors(mesh_obj, pins, cat_array):
    """Vertex color por categoria, pra olhar."""
    me = mesh_obj.data
    # Remove se ja existe
    if "pin_preview" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["pin_preview"])
    col = me.color_attributes.new(name="pin_preview", type='FLOAT_COLOR', domain='POINT')

    # Paleta por categoria (RGBA, perceptualmente distintas)
    palette = {
        "FACE":       (1.00, 0.30, 0.30, 1.0),  # vermelho — rigido critico
        "CRANIO":     (0.80, 0.10, 0.10, 1.0),  # vermelho escuro
        "CABELO":     (0.20, 0.80, 1.00, 1.0),  # ciano — jiggle leve
        "MAO":        (1.00, 0.70, 0.20, 1.0),  # laranja — rigido
        "PE":         (0.90, 0.60, 0.10, 1.0),  # laranja escuro
        "CORPO":      (0.20, 0.90, 0.40, 1.0),  # verde — corpo semi-rigido
        "ROBE_MANGA": (0.30, 0.30, 0.95, 1.0),  # azul — drape
        "OUTRO":      (0.60, 0.60, 0.60, 1.0),  # cinza
    }
    for vi in range(len(me.vertices)):
        col.data[vi].color = palette.get(cat_array[vi], (1, 0, 1, 1))


def build_preview_material():
    """Material Emission que mostra a vertex color crua, sem lighting. NAO aplica
    no mesh — caller decide quando trocar (so durante render dos PNGs heatmap)."""
    mat = bpy.data.materials.new("PinPreviewMat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    attr = nt.nodes.new('ShaderNodeAttribute')
    attr.attribute_name = "pin_preview"
    em   = nt.nodes.new('ShaderNodeEmission')
    out  = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(attr.outputs['Color'], em.inputs['Color'])
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    return mat


def swap_materials(mesh_obj, new_mat):
    """Substitui materiais do mesh, retorna lista original pra restaurar depois."""
    me = mesh_obj.data
    saved = list(me.materials)
    me.materials.clear()
    me.materials.append(new_mat)
    return saved


def restore_materials(mesh_obj, saved):
    me = mesh_obj.data
    me.materials.clear()
    for m in saved:
        me.materials.append(m)


def setup_camera(name, location, look_at, ortho=True, ortho_scale=1.4):
    cd = bpy.data.cameras.new(name)
    cd.type = 'ORTHO' if ortho else 'PERSP'
    cd.ortho_scale = ortho_scale
    cam = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    # Aponta pro look_at
    direction = mu.Vector(look_at) - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    return cam


def render_view(cam, out_png):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.resolution_x = RES_W
    sc.render.resolution_y = RES_H
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)


def render_legend_png(out_path):
    """PNG simples com a legenda das cores (pra Will saber o que cada cor significa)."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("[legend] PIL indisponivel — pulando legenda")
        return
    items = [
        ("FACE / CRANIO (rigido)",   (255, 76, 76)),
        ("MAO / PE (rigido)",         (255, 178, 51)),
        ("CORPO (pin 0.9)",           (51, 230, 102)),
        ("CABELO (pin 0.4 jiggle)",   (51, 204, 255)),
        ("ROBE / MANGA (pin 0.2)",    (76, 76, 242)),
    ]
    W, H = 480, 30 * len(items) + 20
    img = Image.new('RGBA', (W, H), (30, 30, 30, 255))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
    for i, (label, color) in enumerate(items):
        y = 10 + i * 30
        draw.rectangle([10, y, 40, y + 22], fill=color + (255,))
        draw.text((50, y + 3), label, fill=(240, 240, 240, 255), font=font)
    img.save(out_path)


# ------------------------------------------------------------------ MAIN
def main():
    print("=" * 60)
    print("AUTO PIN MAP — dream rig FREE")
    print("=" * 60)
    print(f"Input:  {IN_GLB}")
    print(f"Output: {OUT_DIR}")

    reset_scene()
    eng = pick_eevee()
    print(f"[engine] {eng}")

    mesh, arm = import_glb()
    print(f"[import] mesh={mesh.name} ({len(mesh.data.vertices)} verts), "
          f"arm={arm.name} ({len(arm.data.bones)} bones)")

    # Classificar
    pins, cats, counts = classify_verts(mesh, arm)
    total = len(pins)
    print("\n[classificacao]")
    for k, v in counts.items():
        pct = 100.0 * v / total
        print(f"  {k:12s} {v:6d} ({pct:5.1f}%)")

    # Gravar vertex group + vertex colors (mas NAO trocar material ainda —
    # preservamos o original pro cloth_test renderizar texturizado depois)
    write_vertex_group(mesh, pins)
    write_preview_colors(mesh, pins, cats)
    preview_mat = build_preview_material()
    print("[grava] vertex group 'cloth_pin' + color attribute 'pin_preview' OK")

    # Renderizar 4 vistas
    bb = [mesh.matrix_world @ mu.Vector(c) for c in mesh.bound_box]
    cx = sum(v.x for v in bb) / 8.0
    cy = sum(v.y for v in bb) / 8.0
    cz = sum(v.z for v in bb) / 8.0
    center = (cx, cy, cz)
    el_rad = math.radians(EL_DEG)

    views = {
        "front": (cx, cy - CAM_DIST, cz + CAM_DIST * math.tan(el_rad)),
        "back":  (cx, cy + CAM_DIST, cz + CAM_DIST * math.tan(el_rad)),
        "side":  (cx + CAM_DIST, cy, cz + CAM_DIST * math.tan(el_rad)),
        "3q":    (cx + CAM_DIST * 0.7, cy - CAM_DIST * 0.7,
                  cz + CAM_DIST * math.tan(el_rad)),
    }
    # Troca material pelo preview SO durante render dos PNGs heatmap
    saved_mats = swap_materials(mesh, preview_mat)
    for name, loc in views.items():
        cam = setup_camera(f"cam_{name}", loc, center)
        out_png = os.path.join(OUT_DIR, f"auto_pin_{name}.png")
        render_view(cam, out_png)
        print(f"[render] {out_png}")
    # Restaura textura original pro .blend salvo ficar usavel pelo cloth_test
    restore_materials(mesh, saved_mats)
    print(f"[mat] restaurados {len(saved_mats)} materiais originais no mesh")

    # Legenda
    render_legend_png(os.path.join(OUT_DIR, "auto_pin_LEGEND.png"))
    print("[render] legenda salva")

    # Salvar .blend separado (NAO toca soph_rig_wip.blend)
    blend_path = os.path.join(OUT_DIR, "soph_auto_pin.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[blend]  {blend_path}")

    # Stats JSON
    stats = {
        "input_glb": IN_GLB,
        "total_verts": int(total),
        "categories": {k: int(v) for k, v in counts.items()},
        "thresholds": {"R_FACE": R_FACE, "R_BODY": R_BODY, "R_ARM": R_ARM},
        "pin_values": {"RIGID": PIN_RIGID, "BODY": PIN_BODY,
                       "HAIR": PIN_HAIR, "DRAPE": PIN_DRAPE},
    }
    stats_path = os.path.join(OUT_DIR, "auto_pin_stats.json")
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)
    print(f"[stats]  {stats_path}")

    print("\n" + "=" * 60)
    print("PRONTO — abre os 4 PNGs e olha se cada regiao ficou na cor certa")
    print("  vermelho = face/cranio (rigido)")
    print("  laranja  = maos/pes (rigido)")
    print("  verde    = corpo (pin 0.9)")
    print("  ciano    = cabelo (pin 0.4)")
    print("  azul     = robe/manga (pin 0.2, drape)")
    print("Se algo ficou errado, ajusta R_FACE / R_BODY / R_ARM no topo do script")
    print("=" * 60)


if __name__ == "__main__":
    main()

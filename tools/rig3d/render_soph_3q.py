"""Render da Soph 3D rigada -> sequencia de PNG numa camera 3/4 (cel + contorno).

Roda DENTRO do Blender (headless):
  blender --background --python tools/rig3d/render_soph_3q.py -- \
    --fbx tools/rig3d/in/soph_idle.fbx --out tools/rig3d/out/idle \
    --res 512x768 --az 35 --el 12 --outline 0.02 [--toon]

Faz:
  - importa o FBX (mesh + armature + animacao do Mixamo);
  - camera ORTOGRAFICA em 3/4 (azimute --az, elevacao --el) mirando o personagem;
  - contorno preto por INVERTED-HULL (Solidify + normais invertidas + emissao preta);
  - (opcional) toon/cel-shade por rampa no diffuse (--toon);
  - filme TRANSPARENTE; renderiza todos os frames da acao pra PNG.
Nao da pra testar sem Blender+mesh: ajustes finos (az/el/ortho/outline) no olho.
"""
import bpy, sys, os, math, mathutils

def _argv():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []

def _opt(args, name, default=None):
    return args[args.index(name) + 1] if name in args else default

def _flag(args, name):
    return name in args

def main():
    args = _argv()
    fbx     = _opt(args, "--fbx")
    out_dir = _opt(args, "--out", "tools/rig3d/out/idle")
    res     = _opt(args, "--res", "512x768")
    az      = float(_opt(args, "--az", "35"))
    el      = float(_opt(args, "--el", "12"))
    ortho   = _opt(args, "--ortho", None)
    outline = float(_opt(args, "--outline", "0.02"))
    toon    = _flag(args, "--toon")
    if not fbx:
        print("ERRO: passe --fbx <arquivo>"); return
    rw, rh = (int(x) for x in res.lower().split("x"))
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    # cena limpa
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    # engine Eevee (5.x = BLENDER_EEVEE; 4.2-4.x = BLENDER_EEVEE_NEXT)
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng; break
        except Exception:
            continue

    bpy.ops.import_scene.fbx(filepath=os.path.abspath(fbx))

    meshes = [o for o in scene.objects if o.type == "MESH"]
    arms   = [o for o in scene.objects if o.type == "ARMATURE"]
    if not meshes:
        print("ERRO: nenhum mesh no FBX"); return

    # bounding box do conjunto -> alvo e tamanho
    mn = mathutils.Vector(( 1e9,  1e9,  1e9))
    mx = mathutils.Vector((-1e9, -1e9, -1e9))
    for ob in meshes:
        for c in ob.bound_box:
            w = ob.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn[i], w[i]) for i in range(3)))
            mx = mathutils.Vector((max(mx[i], w[i]) for i in range(3)))
    center = (mn + mx) * 0.5
    height = (mx.z - mn.z) or 2.0

    # alvo da camera (empty no centro)
    tgt = bpy.data.objects.new("tgt", None)
    tgt.location = center
    scene.collection.objects.link(tgt)

    # camera ortografica em 3/4
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = float(ortho) if ortho else height * 1.15
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    raz, rel = math.radians(az), math.radians(el)
    dist = max(height * 4.0, 5.0)
    # Mixamo encara -Y; 3/4 = girar no entorno do eixo Z + elevar
    dirv = mathutils.Vector((math.sin(raz) * math.cos(rel),
                             -math.cos(raz) * math.cos(rel),
                             math.sin(rel)))
    cam.location = center + dirv * dist
    con = cam.constraints.new("TRACK_TO")
    con.target = tgt
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    scene.camera = cam

    # luz flat (sol frontal-alto) + fill ambiente
    sun_d = bpy.data.lights.new("sun", "SUN"); sun_d.energy = 3.0
    sun = bpy.data.objects.new("sun", sun_d)
    sun.rotation_euler = (math.radians(55), 0, math.radians(az + 20))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w"); scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.6, 0.6, 0.62, 1.0)
        bg.inputs[1].default_value = 0.7

    # toon opcional: rampa de poucos passos no diffuse
    if toon:
        for ob in meshes:
            for slot in ob.material_slots:
                m = slot.material
                if not m or not m.use_nodes:
                    continue
                nt = m.node_tree
                bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if bsdf:
                    bsdf.inputs["Roughness"].default_value = 1.0
                    if "Specular IOR Level" in bsdf.inputs:
                        bsdf.inputs["Specular IOR Level"].default_value = 0.0

    # contorno preto: inverted-hull (Solidify + flip + material emissivo preto)
    if outline > 0:
        blk = bpy.data.materials.new("outline_black")
        blk.use_nodes = True
        nt = blk.node_tree; nt.nodes.clear()
        emit = nt.nodes.new("ShaderNodeEmission")
        emit.inputs[0].default_value = (0, 0, 0, 1)
        outp = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(emit.outputs[0], outp.inputs[0])
        blk.use_backface_culling = True
        for ob in meshes:
            idx = len(ob.data.materials)
            ob.data.materials.append(blk)
            mod = ob.modifiers.new("outline", "SOLIDIFY")
            mod.thickness = -abs(outline)
            mod.offset = 1.0
            mod.use_flip_normals = True
            mod.material_offset = idx
            mod.use_rim = False

    # frame range pela acao do Mixamo
    fs, fe = scene.frame_start, scene.frame_end
    if arms and arms[0].animation_data and arms[0].animation_data.action:
        r = arms[0].animation_data.action.frame_range
        fs, fe = int(r[0]), int(r[1])
    scene.frame_start, scene.frame_end = fs, fe

    # saida PNG transparente
    scene.render.resolution_x = rw
    scene.render.resolution_y = rh
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = os.path.join(out_dir, "f")

    print("[render] frames %d..%d  res %dx%d  az %.0f el %.0f -> %s"
          % (fs, fe, rw, rh, az, el, out_dir))
    bpy.ops.render.render(animation=True)
    print("[render] OK")

main()

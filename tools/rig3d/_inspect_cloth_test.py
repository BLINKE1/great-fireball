"""Quick inspect: o que tem dentro de soph_cloth_test.blend."""
import bpy, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "soph_cloth_test.blend")

bpy.ops.wm.open_mainfile(filepath=BLEND)

print("=" * 60)
print(f"Scene: {bpy.context.scene.name}")
print(f"Frame current: {bpy.context.scene.frame_current}")
print(f"Frame start/end: {bpy.context.scene.frame_start}/{bpy.context.scene.frame_end}")
print(f"Camera ativa: {bpy.context.scene.camera.name if bpy.context.scene.camera else 'NENHUMA'}")
print("=" * 60)
print(f"Objetos na cena ({len(bpy.data.objects)}):")
for o in bpy.data.objects:
    bb = o.bound_box
    dims = o.dimensions
    print(f"  [{o.type:8s}] {o.name:30s} pos={tuple(round(v,2) for v in o.location)} dims={tuple(round(v,2) for v in dims)}")
    if o.type == 'MESH':
        print(f"             verts={len(o.data.vertices)} modifiers={[m.type for m in o.modifiers]}")
        for vg in o.vertex_groups:
            if 'cloth' in vg.name.lower() or 'pin' in vg.name.lower():
                print(f"             vgroup: {vg.name}")

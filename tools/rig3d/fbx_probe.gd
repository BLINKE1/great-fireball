extends SceneTree
## fbx_probe.gd — inspeciona o soph_rigged.fbx: esqueleto, animacoes, meshes.
##   "$GODOT" --headless -s tools/rig3d/fbx_probe.gd
func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://tools/rig3d/in/soph_rigged.fbx")
	var doc := FBXDocument.new()
	var st := FBXState.new()
	var err := doc.append_from_file(path, st)
	print("[probe] append err=", err)
	if err != OK:
		quit(1); return
	var scene := doc.generate_scene(st)
	if scene == null:
		print("[probe] generate_scene null"); quit(1); return
	_walk(scene, 0)
	quit(0)

func _walk(n: Node, d: int) -> void:
	var pad := ""
	for i in d: pad += "  "
	print(pad, n.get_class(), " '", n.name, "'")
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		print(pad, "  BONES=", sk.get_bone_count())
		for i in sk.get_bone_count():
			print(pad, "   [", i, "] ", sk.get_bone_name(i), "  parent=", sk.get_bone_parent(i))
	if n is AnimationPlayer:
		print(pad, "  ANIMS=", (n as AnimationPlayer).get_animation_list())
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		print(pad, "  AABB=", (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_walk(c, d + 1)

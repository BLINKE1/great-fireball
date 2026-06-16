extends SceneTree
## Smoke test do soph_rig.tscn:
## - Carrega a cena
## - Verifica que Skeleton2D existe + tem 15 Bone2D + 11 Sprite2D
## - Imprime posicao global de cada bone e cada sprite (sanity)
##   $GODOT --headless -s tools/rig_smoke.gd

func _initialize() -> void:
	var path := "res://scenes/characters/soph_rig.tscn"
	var packed = load(path)
	if packed == null:
		printerr("x FALHOU load: ", path)
		quit(1); return
	var rig = packed.instantiate()
	get_root().add_child(rig)

	var skel = rig.get_node_or_null("Skeleton2D")
	if skel == null:
		printerr("x Skeleton2D ausente")
		quit(1); return

	var bones: Array[Node] = []
	var sprites: Array[Node] = []
	_collect(skel, bones, sprites)
	print("bones encontrados: ", bones.size())
	print("sprites encontrados: ", sprites.size())

	for b in bones:
		print("  BONE %s  global=%s  rest=%s" % [b.name, b.global_position, b.rest])
	for s in sprites:
		print("  SPRITE %s  global=%s  z=%d  tex=%s" % [
			s.name, s.global_position, s.z_index,
			(s.texture.resource_path if s.texture else "<null>")
		])

	if bones.size() != 15 or sprites.size() != 11:
		printerr("x contagem inesperada (esperado 15 bones + 11 sprites)")
		quit(1); return

	for s in sprites:
		if s.texture == null:
			printerr("x sprite sem textura: ", s.name)
			quit(1); return

	print("\nSMOKE OK ✓")
	quit(0)


func _collect(node: Node, bones: Array, sprites: Array) -> void:
	if node is Bone2D:
		bones.append(node)
	elif node is Sprite2D:
		sprites.append(node)
	for c in node.get_children():
		_collect(c, bones, sprites)

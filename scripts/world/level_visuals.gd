extends Node

# Attach to any level root. Adds parallax cave background, stone tile textures
# on all platforms/floors, atmospheric modulate, and point lights.

func _ready() -> void:
	var level := get_parent()
	_add_solid_background(level)
	_add_parallax(level)
	_add_canvas_modulate(level)
	_apply_stone_textures(level)
	_apply_special_objects(level)
	_add_point_lights(level)

# ── Solid background (behind parallax) ───────────────────────────────────────

func _add_solid_background(level: Node) -> void:
	var cl := CanvasLayer.new()
	cl.name = "CaveBG"
	cl.layer = -100
	level.add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.012, 0.006, 0.032)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(rect)

# ── Parallax cave layers ──────────────────────────────────────────────────────

func _add_parallax(level: Node) -> void:
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBG"
	level.add_child(pb)
	level.move_child(pb, 0)

	var far_tex := SpriteSetup.get_texture("cave_far")
	var mid_tex := SpriteSetup.get_texture("cave_mid")

	# Far layer — barely moves (0.08x horizontal). Sprite y=-250 covers ceiling area.
	if far_tex:
		_add_layer(pb, far_tex, Vector2(0.08, 0.08), Vector2(512, 0), Vector2(0, -250))
	# Mid layer — medium speed (0.22x). Larger stalactites.
	if mid_tex:
		_add_layer(pb, mid_tex, Vector2(0.22, 0.16), Vector2(256, 0), Vector2(0, -250))

func _add_layer(pb: ParallaxBackground, tex: ImageTexture, scale: Vector2,
		mirror: Vector2, offset: Vector2) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = scale
	layer.motion_mirroring = mirror
	pb.add_child(layer)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)

# ── Atmospheric cave tint ─────────────────────────────────────────────────────

func _add_canvas_modulate(level: Node) -> void:
	var cm := CanvasModulate.new()
	cm.name = "CaveAtmosphere"
	cm.color = Color(0.80, 0.72, 0.96)
	level.add_child(cm)

# ── Stone tile textures on all platforms/floors/walls ─────────────────────────

func _apply_stone_textures(level: Node) -> void:
	var ft := SpriteSetup.get_texture("floor_tile")
	var pt := SpriteSetup.get_texture("platform_tile")
	var wt := SpriteSetup.get_texture("wall_tile")
	_visit(level, ft, pt, wt)

func _visit(node: Node, ft: ImageTexture, pt: ImageTexture, wt: ImageTexture) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.texture is PlaceholderTexture2D:
			var sz: Vector2 = child.texture.get_size()
			var aspect := sz.x / sz.y
			var tex: ImageTexture
			if   aspect >= 8.0:  tex = ft   # very wide → floor
			elif aspect >= 3.5:  tex = pt   # wide → platform
			elif aspect <= 0.40: tex = wt   # tall → wall
			# square-ish (aspect ~1) = special object, skip
			if tex:
				child.texture = tex
				child.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				child.region_enabled = true
				child.region_rect = Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y)
				child.modulate = Color.WHITE
				child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_visit(child, ft, pt, wt)

# ── Named special objects ─────────────────────────────────────────────────────

func _apply_special_objects(level: Node) -> void:
	# Tutorial level chest
	var chest := level.get_node_or_null("Environment/Chest")
	if chest is Sprite2D:
		var tex := SpriteSetup.get_texture("chest")
		if tex:
			chest.texture = tex
			chest.modulate = Color.WHITE
			chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# ── Atmospheric point lights ──────────────────────────────────────────────────

func _add_point_lights(level: Node) -> void:
	var light_tex := SpriteSetup.get_texture("light_tex")
	if not light_tex:
		return
	if level.has_node("DungeonManager"):
		_add_dungeon_lights(level, light_tex)
	else:
		_add_tutorial_lights(level, light_tex)

func _add_tutorial_lights(level: Node, light_tex: ImageTexture) -> void:
	# Warm torch-orange lights scattered across the play area
	_make_light(level, Vector2(640, 430), Color(1.00, 0.56, 0.16), 0.70, 4.2, light_tex)
	_make_light(level, Vector2(250, 340), Color(0.95, 0.48, 0.12), 0.55, 3.4, light_tex)
	_make_light(level, Vector2(960, 360), Color(1.00, 0.60, 0.20), 0.60, 3.6, light_tex)
	# Cool magical light near where spells are cast
	_make_light(level, Vector2(620, 260), Color(0.62, 0.40, 1.00), 0.42, 2.8, light_tex)

func _add_dungeon_lights(level: Node, light_tex: ImageTexture) -> void:
	var warm  := Color(1.00, 0.54, 0.14)
	var cool  := Color(0.58, 0.38, 1.00)
	var eerie := Color(0.28, 0.88, 0.44)
	# Entrance area (x 0–900)
	_make_light(level, Vector2(300,  420), warm,  0.65, 4.0, light_tex)
	_make_light(level, Vector2(720,  370), cool,  0.45, 3.2, light_tex)
	# Mid-left (x 900–2000)
	_make_light(level, Vector2(1100, 440), warm,  0.72, 4.5, light_tex)
	_make_light(level, Vector2(1500, 380), cool,  0.50, 3.6, light_tex)
	_make_light(level, Vector2(1900, 430), warm,  0.68, 4.2, light_tex)
	# Center (x 2000–3200)
	_make_light(level, Vector2(2350, 400), cool,  0.48, 3.5, light_tex)
	_make_light(level, Vector2(2750, 430), warm,  0.74, 4.8, light_tex)
	_make_light(level, Vector2(3100, 380), cool,  0.52, 3.6, light_tex)
	# Mid-right (x 3200–4200)
	_make_light(level, Vector2(3500, 440), warm,  0.70, 4.3, light_tex)
	_make_light(level, Vector2(3900, 390), cool,  0.48, 3.4, light_tex)
	# Boss arena (x 4200–5500) — eerie green tones
	_make_light(level, Vector2(4200, 420), eerie, 0.58, 4.0, light_tex)
	_make_light(level, Vector2(4500, 380), eerie, 0.72, 4.6, light_tex)
	_make_light(level, Vector2(4800, 430), eerie, 0.62, 4.2, light_tex)
	_make_light(level, Vector2(5100, 400), warm,  0.52, 3.5, light_tex)

func _make_light(level: Node, pos: Vector2, color: Color, energy: float,
		tex_scale: float, light_tex: ImageTexture) -> void:
	var light := PointLight2D.new()
	light.texture = light_tex
	light.color = color
	light.energy = energy
	light.texture_scale = tex_scale
	light.position = pos
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	level.add_child(light)
	# Subtle random flicker via looping tween
	var e_lo := energy * randf_range(0.78, 0.92)
	var e_hi := energy * randf_range(0.96, 1.08)
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "energy", e_lo, randf_range(0.45, 1.10)).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(light, "energy", e_hi, randf_range(0.45, 1.10)).set_ease(Tween.EASE_IN_OUT)

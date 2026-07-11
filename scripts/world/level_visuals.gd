extends Node

# Attach to any level root. Adds parallax background, tile textures on all
# platforms/floors, atmospheric modulate, and point lights.
# Níveis com DungeonManager usam o tema FLORESTA (céu de entardecer, parallax
# de árvores, tiles de grama); o resto (tutorial) usa o tema caverna.

var _forest := false
# TESTE (pedido do Will): tema CAVERNA — no' "CaveTheme" na cena troca o
# backdrop pela caverna John Avon (parede total, estilo Terraria) e corta
# arvores/arbustos. O resto (chao musgado, backwalls de plataforma) fica.
var _cave := false

# Foreground (folhagem da frente): arbustos subindo da BASE da tela 640x360.
const FG_SCALE := 0.55
const FG_VP_H := 360.0   # altura do viewport (ancora a folhagem no chao da tela)
const FG_Y := 8.0        # nudge: +desce (deixa a base pra fora), -sobe

func _ready() -> void:
	# Adia a montagem p/ DEPOIS que o pai termina de instanciar seus filhos.
	# Sem isso, add_child() durante o _ready do pai falha com "Parent node is
	# busy setting up children" — e luzes/partículas não entravam na cena.
	_build.call_deferred()

func _build() -> void:
	var level := get_parent()
	if level == null:
		return
	_forest = level.has_node("DungeonManager")
	_cave = level.has_node("CaveTheme")
	_add_solid_background(level)
	_add_parallax(level)
	if _forest and not _cave:
		_scatter_trees(level)
		_add_foreground(level)
	_add_canvas_modulate(level)
	_apply_stone_textures(level)
	_apply_special_objects(level)
	_add_point_lights(level)
	_add_ambient_particles(level)

func _add_ambient_particles(level: Node) -> void:
	var AmbientScript = load("res://scripts/world/ambient_particles.gd")
	if not AmbientScript:
		return
	var ap = AmbientScript.new()
	ap.area_width    = 5200.0 if level.has_node("DungeonManager") else 3800.0
	ap.area_height   = 580.0
	ap.particle_count = 40 if level.has_node("DungeonManager") else 25
	ap.forest = _forest      # floresta → vaga-lumes
	level.add_child(ap)

# ── Solid background (behind parallax) ───────────────────────────────────────

func _add_solid_background(level: Node) -> void:
	var cl := CanvasLayer.new()
	cl.name = "CaveBG"
	cl.layer = -100
	level.add_child(cl)
	if _forest:
		# Backdrop pintado (John Avon) se houver PNG; senao gradiente de entardecer.
		# Tema caverna: a parede pintada vira o fundo TODO (Terraria full-wall).
		var bd_path := "res://assets/sprites/backgrounds/cave_backdrop.png" if _cave \
				else "res://assets/sprites/backgrounds/forest_backdrop.png"
		var backdrop := _load_backdrop(bd_path)
		var tr := TextureRect.new()
		if backdrop != null:
			tr.texture = backdrop
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			var grad := Gradient.new()
			grad.offsets = PackedFloat32Array([0.0, 0.50, 0.70, 0.84, 1.0])
			grad.colors = PackedColorArray([
				Color(0.10, 0.12, 0.25), Color(0.21, 0.16, 0.27),
				Color(0.36, 0.23, 0.25), Color(0.13, 0.19, 0.15), Color(0.06, 0.10, 0.08)])
			var gtex := GradientTexture2D.new()
			gtex.gradient = grad
			gtex.fill_from = Vector2(0, 0); gtex.fill_to = Vector2(0, 1)
			gtex.width = 64; gtex.height = 256
			tr.texture = gtex
			tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(tr)
	else:
		var rect := ColorRect.new()
		rect.color = Color(0.012, 0.006, 0.032)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cl.add_child(rect)

# ── Foreground (folhagem na FRENTE, "perto da tela" estilo HK) ───────────────
func _add_foreground(level: Node) -> void:
	var tex := _load_backdrop("res://assets/sprites/backgrounds/forest_foreground.png")
	if tex == null:
		return
	var pb := ParallaxBackground.new()
	pb.name = "ForegroundPB"
	pb.layer = 5                        # frente do gameplay (0), atras da UI (>=8)
	level.add_child(pb)
	var lay := ParallaxLayer.new()
	lay.motion_scale = Vector2(1.35, 0.0)   # x: rola mais rapido (perto da tela); y=0: ancora vertical na tela
	var iw: float = tex.get_width() * FG_SCALE
	lay.motion_mirroring = Vector2(iw, 0)   # tileia na horizontal
	pb.add_child(lay)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(FG_SCALE, FG_SCALE)
	# ancora a BASE dos arbustos no chao da tela (sensacao de perto do player)
	var strip_h: float = tex.get_height() * FG_SCALE
	spr.position = Vector2(0, FG_VP_H - strip_h + FG_Y)
	spr.modulate = Color(1, 1, 1, 0.92)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lay.add_child(spr)

# Carrega o backdrop pintado (importado ou PNG cru). null se nao existir.
func _load_backdrop(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null

# ── Parallax cave layers ──────────────────────────────────────────────────────

func _add_parallax(level: Node) -> void:
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBG"
	level.add_child(pb)
	level.move_child(pb, 0)

	var far_tex := SpriteSetup.get_texture("forest_far" if _forest else "cave_far")
	var mid_tex := SpriteSetup.get_texture("forest_mid" if _forest else "cave_mid")

	if _forest:
		# O céu de floresta é o gradiente de _add_solid_background (sempre visível).
		# O parallax de árvores não renderiza no contexto da dungeon (limites de
		# câmera), então fica desligado aqui — a linha de árvores vive no gradiente.
		pass
	else:
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

# ── Árvores decorativas no mundo (floresta) ──────────────────────────────────
func _scatter_trees(level: Node) -> void:
	var tex := SpriteSetup.get_texture("forest_tree")
	if tex == null:
		return
	seed(808)
	var x := 120.0
	var tex_h := tex.get_size().y      # ancora a BASE no chao p/ qualquer textura
	# alvo: arvores ~260-380px no mundo (a Avon tem 220px; a procedural, 128)
	var s_lo := 260.0 / tex_h
	var s_hi := 380.0 / tex_h
	while x < 5350.0:
		var spr := Sprite2D.new()
		spr.texture = tex
		# Avon (pintada, >=200px) usa filtro suave; procedural segue pixel
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if tex_h >= 200.0 \
				else CanvasItem.TEXTURE_FILTER_NEAREST
		var s := randf_range(s_lo, s_hi)
		spr.scale = Vector2(s, s)
		spr.position = Vector2(x, 492.0 - tex_h * 0.5 * s)   # base no topo do chão
		spr.z_index = -5                              # atrás do gameplay
		var d := randf()                              # profundidade: árvores ao fundo + escuras/azuis
		spr.modulate = Color(0.52 + 0.26 * d, 0.60 + 0.24 * d, 0.56 + 0.20 * d, 0.92)
		spr.flip_h = randf() < 0.5
		spr.add_to_group("forest_tree")   # cinematica do boss balanca as arvores
		level.add_child(spr)
		x += randf_range(300.0, 560.0)

# ── Atmospheric cave tint ─────────────────────────────────────────────────────

func _add_canvas_modulate(level: Node) -> void:
	var cm := CanvasModulate.new()
	cm.name = "CaveAtmosphere"
	# luar de floresta / breu esverdeado de caverna / roxo da caverna antiga
	cm.color = (Color(0.74, 0.86, 0.84) if _cave else Color(0.88, 0.93, 0.88)) if _forest \
			else Color(0.80, 0.72, 0.96)
	level.add_child(cm)

# ── Stone tile textures on all platforms/floors/walls ─────────────────────────

func _apply_stone_textures(level: Node) -> void:
	var ft := SpriteSetup.get_texture("grass_floor" if _forest else "floor_tile")
	var pt := SpriteSetup.get_texture("grass_platform" if _forest else "platform_tile")
	var wt := SpriteSetup.get_texture("moss_wall" if _forest else "wall_tile")
	_visit(level, ft, pt, wt)

# Texture2D (nao ImageTexture): tiles vindos de override PNG reimportado chegam
# como CompressedTexture2D; os procedurais continuam ImageTexture. Aceitar ambos.
func _visit(node: Node, ft: Texture2D, pt: Texture2D, wt: Texture2D) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.texture is PlaceholderTexture2D:
			var sz: Vector2 = child.texture.get_size()
			var aspect := sz.x / sz.y
			var tex: Texture2D
			# FINO (<=28px) e largo = plataforma, mesmo com aspect enorme —
			# antes 180x16 caia em aspect>=8 e virava "chao" (bug antigo: as
			# plataformas nunca recebiam o proprio tile).
			if   aspect >= 3.5 and sz.y <= 28.0: tex = pt   # ledge fino → platform
			elif aspect >= 8.0:  tex = ft   # largo e fundo → floor
			elif aspect >= 3.5:  tex = pt   # wide → platform
			elif aspect <= 0.40: tex = wt   # tall → wall
			# square-ish (aspect ~1) = special object, skip
			if tex:
				child.texture = tex
				child.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				child.region_enabled = true
				# regiao ancorada em (0,0): a linha 0 da textura (faixa de grama)
				# cola no TOPO do sprite pra QUALQUER altura. Ancorar em -sz/2
				# (antigo) poe a grama no meio do chao quando a altura nao e'
				# multipla de 32.
				var draw_h := sz.y
				if tex == pt and _forest and tex.get_height() >= 80:
					# plataforma pintada: RAIZES penduradas abaixo do collider
					# (overhang so' visual — a fisica nao muda). offset desce o
					# desenho pra manter o topo alinhado com o topo do corpo.
					var overhang := minf(40.0, tex.get_height() - sz.y)
					draw_h = sz.y + overhang
					child.offset = Vector2(0, overhang * 0.5)
					# tecnica TERRARIA: parede de fundo atras da plataforma ate'
					# o chao -> "encosta/caverna", a plataforma vira bancada
					# embutida em vez de tile flutuante.
					_add_backwall(child, sz)
				child.region_rect = Rect2(0, 0, sz.x, draw_h)
				child.modulate = Color.WHITE
				# floresta = tiles pintados premium (512px, gen_forest_ground.py)
				# -> filtro suave, mesmo registro do backdrop. Pedra/caverna
				# segue pixel-art NEAREST.
				child.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _forest \
						else CanvasItem.TEXTURE_FILTER_NEAREST
		_visit(child, ft, pt, wt)

# ── Parede de fundo (tecnica Terraria) atras das plataformas da floresta ──────
# Mesma rocha musgada dos paredoes, so' que ESCURA e atras do gameplay: leitura
# imediata de "interior da encosta". Vai de um pouco acima da plataforma ate'
# dentro do chao (o piso cobre a emenda). z=-4: frente das arvores (-5), atras
# de tudo que joga.
const BACKWALL_GROUND_Y := 520.0

func _add_backwall(plat_sprite: Sprite2D, sz: Vector2) -> void:
	var tex := SpriteSetup.get_texture("moss_wall")
	if tex == null:
		return
	# coords LOCAIS do corpo da plataforma (o wall vira filho dele)
	var top_local := -sz.y * 0.5 - 64.0
	var bottom_local := BACKWALL_GROUND_Y - plat_sprite.global_position.y
	var h := bottom_local - top_local
	if h <= 0.0:
		return
	var w := sz.x + 44.0
	var cy := top_local + h * 0.5
	# jitter deterministico por posicao (mesma cara a cada load)
	var jit := fposmod(plat_sprite.global_position.x * 0.137, 1.0) - 0.5
	# 2 camadas com rotacao levemente oposta: quebra o retangulo "painel de UI"
	# e le como face de rocha. A de tras e' maior e mais escura (silhueta).
	var specs := [
		[w + 30.0, h + 18.0, Color(0.22, 0.28, 0.27, 0.95),  jit * 0.07 - 0.02],
		[w,        h,        Color(0.38, 0.47, 0.44, 0.97), -jit * 0.06 + 0.015],
	]
	for sp in specs:
		var wall := Sprite2D.new()
		wall.texture = tex
		wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_enabled = true
		wall.region_rect = Rect2(0, 0, sp[0], sp[1])
		wall.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		wall.z_index = -4
		wall.modulate = sp[2]
		wall.rotation = sp[3]
		wall.position = Vector2(0, cy)
		plat_sprite.get_parent().add_child.call_deferred(wall)

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

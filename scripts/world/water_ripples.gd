extends Node2D

# Ondas circulares na agua quando a Soph vadeia (tema alagados):
#  - PASSOS: emissao por distancia andada no chao (rastro de aneis) + plip suave.
#  - POUSO: splash maior + gotas (VFX) + som.
#  - ACOES: castar/atacar/tomar dano na agua -> onda + gotas + som.
# Aneis ELIPTICOS (foreshortened) que expandem e somem, desenhados sobre a agua.
# Alem do visual, ALIMENTA o shader do lago (_water_mat) com as ondas ativas p/
# distorcer o REFLEXO radialmente (o "molhado" de verdade).

var player: Node2D = null
var water_y: float = 484.0          # y da superficie (mundo)
var feet_off: float = 26.0          # do origin do player ate' os pes
var water_mat: ShaderMaterial = null # p/ distorcer o reflexo (opcional)

const STEP_DIST := 44.0
const NEAR_TOL := 34.0
const MAX_GPU := 10                  # slots de onda no shader

var _ripples: Array = []            # x,y,age,life,max_r,squash,width,alpha0,warp
var _last_x: float = 0.0
var _acc: float = 0.0
var _was_near := false
var _started := false
var _prev_anim := ""
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	if player != null:
		_sprite = player.get_node_or_null("Sprite2D") as AnimatedSprite2D

func _process(delta: float) -> void:
	var near := false
	if player != null and is_instance_valid(player):
		var px: float = player.global_position.x
		var feet_y: float = player.global_position.y + feet_off
		near = absf(feet_y - water_y) < NEAR_TOL
		if not _started:
			_last_x = px; _started = true
		var dx: float = absf(px - _last_x)
		if near:
			if not _was_near and _started:
				_splash(px, water_y)                       # POUSO
			else:
				_acc += dx
				if _acc >= STEP_DIST:
					_acc = 0.0
					_ring(px, water_y, 34.0, 0.8, 0.62, 2.3, 1.0)
					_ring(px, water_y, 21.0, 0.74, 0.40, 1.6, 0.7)
					if randf() < 0.5:
						AudioManager.play("water_step")
		_was_near = near
		_last_x = px
		_check_action(px, near)
	# atualiza ripples
	var alive: Array = []
	for r in _ripples:
		r.age += delta
		if r.age < r.life:
			alive.append(r)
	_ripples = alive
	_feed_shader()
	queue_redraw()

# Onda quando a Soph age NA agua (cast/slash/hurt) — le a anim do sprite.
func _check_action(px: float, near: bool) -> void:
	if _sprite == null:
		return
	var a := _sprite.animation
	if a != _prev_anim:
		_prev_anim = a
		if near and (a.begins_with("cast") or a.begins_with("slash") or a.begins_with("hurt")):
			_ring(px, water_y, 46.0, 0.85, 0.6, 2.6, 1.3)
			_ring(px, water_y, 30.0, 0.8, 0.42, 1.9, 1.0)
			_droplets(px, water_y, 9, 70.0)
			AudioManager.play("splash", randf_range(0.95, 1.15))

func _splash(x: float, y: float) -> void:
	_ring(x, y, 42.0, 0.85, 0.62, 2.6, 1.4)
	_ring(x, y, 27.0, 0.8, 0.44, 1.8, 1.0)
	_ring(x, y, 15.0, 0.7, 0.3, 1.4, 0.7)
	_droplets(x, y, 12, 86.0)
	AudioManager.play("splash")

func _droplets(x: float, y: float, count: int, speed: float) -> void:
	VFX.burst(Vector2(x, y - 4.0), self, Color(0.72, 0.90, 1.0, 0.85), count, speed, 300.0)

func _ring(x: float, y: float, max_r: float, life: float, a0: float, w: float, warp: float) -> void:
	_ripples.append({
		"x": x, "y": y, "age": 0.0, "life": life,
		"max_r": max_r, "squash": 0.32, "width": w, "alpha0": a0, "warp": warp,
	})

# Passa as ondas ativas pro shader do lago distorcer o reflexo (mundo->tela).
func _feed_shader() -> void:
	if water_mat == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var xform := vp.get_canvas_transform()
	var vsize := vp.get_visible_rect().size
	var scale := xform.x.length()
	var arr := PackedVector4Array()
	var n := 0
	for r in _ripples:
		if n >= MAX_GPU:
			break
		if r.warp <= 0.0:
			continue
		var t: float = r.age / r.life
		var sp := xform * Vector2(r.x, r.y)
		var rad_px: float = r.max_r * ease(t, 0.42) * scale
		var strength: float = r.warp * (1.0 - t) * (1.0 - t)
		arr.append(Vector4(sp.x / vsize.x, sp.y / vsize.y, rad_px / vsize.x, strength))
		n += 1
	while arr.size() < MAX_GPU:
		arr.append(Vector4(0, 0, 0, 0))
	water_mat.set_shader_parameter("ripples", arr)

func _draw() -> void:
	for r in _ripples:
		var t: float = r.age / r.life
		var rad: float = r.max_r * ease(t, 0.42)
		var a: float = r.alpha0 * (1.0 - t) * (1.0 - t)
		if a <= 0.003:
			continue
		draw_set_transform(Vector2(r.x, r.y), 0.0, Vector2(1.0, r.squash))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 30, Color(0.86, 0.96, 0.93, a), r.width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

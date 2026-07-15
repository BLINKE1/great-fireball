extends Node2D

# Ondas circulares nos pes da Soph quando ela vadeia na agua rasa (tema alagados).
# Emissao por DISTANCIA andada no chao (cadencia de passo) + splash maior no
# pouso. Desenha aneis ELIPTICOS (foreshortened p/ casar com a perspectiva da
# agua) que expandem e somem. Fica numa camada na frente da agua (via parallax
# no level_visuals), com coords em espaco de mundo.

var player: Node2D = null
var water_y: float = 484.0          # y da superficie da agua (mundo)
var feet_off: float = 26.0          # do origin do player ate' os pes

const STEP_DIST := 44.0             # px andados por onda de passo
const NEAR_TOL := 34.0              # |pe - agua| p/ considerar "na agua"

var _ripples: Array = []            # dicts: x,y,age,life,max_r,squash,width,alpha0
var _last_x: float = 0.0
var _acc: float = 0.0
var _was_near := false
var _started := false

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		var px: float = player.global_position.x
		var feet_y: float = player.global_position.y + feet_off
		var near: bool = absf(feet_y - water_y) < NEAR_TOL
		if not _started:
			_last_x = px; _started = true
		var dx: float = absf(px - _last_x)
		if near:
			if not _was_near and _started:
				_splash(px, water_y)                 # POUSO: splash
			else:
				_acc += dx
				if _acc >= STEP_DIST:
					_acc = 0.0
					_ring(px, water_y, 34.0, 0.8, 0.62, 2.3)   # passo
					_ring(px, water_y, 21.0, 0.74, 0.40, 1.6)  # 2o anel
		_was_near = near
		_last_x = px
	var alive: Array = []
	for r in _ripples:
		r.age += delta
		if r.age < r.life:
			alive.append(r)
	_ripples = alive
	queue_redraw()

func _splash(x: float, y: float) -> void:
	_ring(x, y, 40.0, 0.85, 0.6, 2.6)
	_ring(x, y, 26.0, 0.8, 0.42, 1.8)
	_ring(x, y, 14.0, 0.7, 0.3, 1.4)

func _ring(x: float, y: float, max_r: float, life: float, a0: float, w: float) -> void:
	_ripples.append({
		"x": x, "y": y, "age": 0.0, "life": life,
		"max_r": max_r, "squash": 0.32, "width": w, "alpha0": a0,
	})

func _draw() -> void:
	for r in _ripples:
		var t: float = r.age / r.life                 # 0..1
		var rad: float = r.max_r * ease(t, 0.42)       # expande rapido, desacelera
		var a: float = r.alpha0 * (1.0 - t) * (1.0 - t)
		if a <= 0.003:
			continue
		draw_set_transform(Vector2(r.x, r.y), 0.0, Vector2(1.0, r.squash))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 30, Color(0.86, 0.96, 0.93, a), r.width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

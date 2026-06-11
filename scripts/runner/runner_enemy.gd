extends CharacterBody2D
## Inimigo do run-and-gun — FORMA procedural (sem textura), no tamanho do hitbox.
## Tipos:
##   walker — anda no chão, vira na parede/borda
##   hopper — pula em direção ao herói
##   flyer  — PAIRA, MERGULHA no herói e SOBE de novo (comportamento clássico)
##   turret — estacionária, atira na horizontal
## Morre em 1 acerto de míssil; encostar nele mata a Soph (1 hit).

const GRAVITY := 1100.0
const Shot := preload("res://scripts/runner/runner_shot.gd")

var kind: String = "walker"
var hp: int = 1
var hit_r: float = 16.0
var facing: float = -1.0
var alive: bool = true
var drops_power: String = ""

var _t: float = 0.0
var _flash: float = 0.0
var _hero: Node = null

# Flyer
var _fstate: String = "hover"
var _stt: float = 0.0
var _hover_y: float = 0.0
var _dive: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("renemy")
	collision_layer = 0
	collision_mask = 1
	_hero = get_tree().get_first_node_in_group("rhero")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	match kind:
		"walker": r.size = Vector2(22, 22); hit_r = 16.0
		"hopper": r.size = Vector2(20, 18); hit_r = 15.0
		"flyer":  r.size = Vector2(24, 16); hit_r = 15.0
		"turret": r.size = Vector2(22, 18); hit_r = 15.0
	cs.shape = r
	cs.position = Vector2(0, -r.size.y / 2.0)
	add_child(cs)
	_hover_y = global_position.y
	_stt = randf_range(0.6, 1.4)

func _draw() -> void:
	var col := Color(0.6, 1.0, 0.7)
	match kind:
		"hopper": col = Color(1.0, 0.9, 0.5)
		"flyer":  col = Color(0.7, 0.85, 1.0)
		"turret": col = Color(1.0, 0.55, 0.7)
	if _flash > 0.0:
		col = Color(1, 1, 1)
	var fill := Color(col.r, col.g, col.b, 0.18)
	if kind == "turret":
		var rect := Rect2(-11, -16, 22, 16)
		draw_rect(rect, fill, true)
		draw_rect(rect, col, false, 2.0)
		draw_line(Vector2(0, -10), Vector2(facing * 16, -10), col, 3.0)
		draw_circle(Vector2(0, -10), 2.0, Color(1, 0.4, 0.4))
	elif kind == "flyer":
		var flap := sin(_t * 16.0) * 5.0
		var body := PackedVector2Array([Vector2(-9, -8), Vector2(0, -13), Vector2(9, -8), Vector2(0, -3)])
		draw_colored_polygon(body, fill)
		draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), col, 2.0)
		draw_line(Vector2(-9, -8), Vector2(-20, -8 - flap), col, 2.0)   # asas batendo
		draw_line(Vector2(9, -8), Vector2(20, -8 - flap), col, 2.0)
		var eye := Color(1, 0.4, 0.4)
		if _fstate == "dive":
			eye = Color(1, 0.85, 0.2)                                   # "irado" no mergulho
		draw_circle(Vector2(facing * 3, -8), 2.0, eye)
	else:
		var w := 22.0 if kind == "walker" else 20.0
		var h := 22.0 if kind == "walker" else 18.0
		var sq := 1.0
		if kind == "hopper":
			sq = 1.0 + sin(_t * 6.0) * 0.06
		var rect := Rect2(-w / 2.0, -h * sq, w, h * sq)
		draw_rect(rect, fill, true)
		draw_rect(rect, col, false, 2.0)
		draw_circle(Vector2(-4, -h + 8.0), 2.0, col)
		draw_circle(Vector2(4, -h + 8.0), 2.0, col)
		if kind == "walker":
			var legw := sin(_t * 10.0) * 3.0
			draw_line(Vector2(-5, 0), Vector2(-5 + legw, 0), col, 2.0)
			draw_line(Vector2(5, 0), Vector2(5 - legw, 0), col, 2.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	queue_redraw()
	match kind:
		"flyer":
			_flyer(delta)
		"turret":
			if _hero and is_instance_valid(_hero):
				facing = signf(_hero.global_position.x - global_position.x)
			if _t > 1.4:
				_t = 0.0
				var s := Shot.new()
				s.from_enemy = true
				s.vel = Vector2(facing * 230.0, 0.0)
				get_parent().add_child(s)
				s.global_position = global_position + Vector2(facing * 14.0, -10.0)
				AudioManager.play("arrow", 0.8)
		"hopper":
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			elif _t > 1.0:
				_t = 0.0
				velocity.y = -380.0
				if _hero and is_instance_valid(_hero):
					velocity.x = signf(_hero.global_position.x - global_position.x) * 100.0
			move_and_slide()
		_:
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			velocity.x = facing * 48.0
			if is_on_wall():
				facing *= -1.0
			move_and_slide()
	if global_position.y > 860.0:
		queue_free()

func _flyer(delta: float) -> void:
	_stt -= delta
	var hp_pos: Vector2 = global_position
	if _hero and is_instance_valid(_hero):
		hp_pos = _hero.global_position
	match _fstate:
		"hover":
			# paira acima e à frente do herói, oscilando
			var tx: float = hp_pos.x + 60.0 * signf(global_position.x - hp_pos.x + 0.01)
			var ty: float = _hover_y + sin(_t * 3.0) * 8.0
			velocity = (Vector2(tx, ty) - global_position) * 2.2
			facing = signf(hp_pos.x - global_position.x)
			if _stt <= 0.0 and absf(global_position.x - hp_pos.x) < 220.0:
				_fstate = "dive"
				_dive = hp_pos                       # trava o alvo
				_stt = 0.9
				AudioManager.play("detect", 1.3)
		"dive":
			velocity = (_dive - global_position).normalized() * 320.0
			if global_position.distance_to(_dive) < 24.0 or _stt <= 0.0:
				_fstate = "climb"
				_stt = 0.8
		"climb":
			velocity = Vector2(signf(global_position.x - hp_pos.x) * 60.0, -160.0)
			if global_position.y <= _hover_y or _stt <= 0.0:
				_fstate = "hover"
				_stt = randf_range(0.7, 1.4)
	position += velocity * delta

func take_hit() -> void:
	if not alive:
		return
	hp -= 1
	_flash = 0.12
	if hp <= 0:
		_die()

func _die() -> void:
	alive = false
	VFX.burst(global_position + Vector2(0, -10), get_parent(), Color(0.7, 1.0, 0.8), 14, 110.0, 30.0)
	AudioManager.play("enemy_die", randf_range(0.95, 1.1))
	if drops_power != "":
		var mgr := get_parent()
		if mgr and mgr.has_method("spawn_powerup"):
			mgr.spawn_powerup(global_position + Vector2(0, -16), drops_power)
	queue_free()

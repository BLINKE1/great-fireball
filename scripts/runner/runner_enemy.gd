extends CharacterBody2D
## Inimigo do run-and-gun — FORMA procedural (sem textura), no tamanho do hitbox.
## Tipos: "walker" (anda no chão), "hopper" (pula), "flyer" (mergulha voando).
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
		draw_line(Vector2(0, -10), Vector2(facing * 16, -10), col, 3.0)   # cano
		draw_circle(Vector2(0, -10), 2.0, Color(1, 0.4, 0.4))
	elif kind == "flyer":
		var pts := PackedVector2Array([Vector2(-12, -8), Vector2(0, -15), Vector2(12, -8), Vector2(0, -1)])
		draw_colored_polygon(pts, fill)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 2.0)
		draw_line(Vector2(-12, -8), Vector2(-21, -13), col, 2.0)   # asas
		draw_line(Vector2(12, -8), Vector2(21, -13), col, 2.0)
		draw_circle(Vector2(0, -8), 2.0, Color(1, 0.4, 0.4))
	else:
		var w := 22.0 if kind == "walker" else 20.0
		var h := 22.0 if kind == "walker" else 18.0
		var rect := Rect2(-w / 2.0, -h, w, h)
		draw_rect(rect, fill, true)
		draw_rect(rect, col, false, 2.0)
		draw_circle(Vector2(-4, -h + 8.0), 2.0, col)
		draw_circle(Vector2(4, -h + 8.0), 2.0, col)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	queue_redraw()
	match kind:
		"flyer":
			if _hero and is_instance_valid(_hero):
				velocity.x = signf(_hero.global_position.x - global_position.x) * 72.0
			velocity.y = sin(_t * 4.0) * 70.0
			position += velocity * delta
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
				velocity.y = -370.0
				if _hero and is_instance_valid(_hero):
					velocity.x = signf(_hero.global_position.x - global_position.x) * 95.0
			move_and_slide()
		_:
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			velocity.x = facing * 46.0
			if is_on_wall():
				facing *= -1.0
			move_and_slide()
	if global_position.y > 820.0:
		queue_free()

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

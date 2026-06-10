extends CharacterBody2D
## Primeiro boss do estágio — uma MÁQUINA (design original, forma procedural).
## Paira, telegrafa e solta bombas. Tem HP (ao contrário do herói, que morre em 1
## hit). Encostar nela mata a Soph. Ao morrer: estágio concluído.

signal defeated

const Shot := preload("res://scripts/runner/runner_shot.gd")

var hp: int = 24
var max_hp: int = 24
var hit_r: float = 48.0
var alive: bool = true
var pattern: int = 1
var _alt: int = 0

var _home: Vector2
var _t: float = 0.0
var _flash: float = 0.0
var _atk: float = 1.2
var _telegraph: float = 0.0

func _ready() -> void:
	add_to_group("rboss")
	collision_layer = 0
	collision_mask = 0
	_home = global_position

func _draw() -> void:
	var c := Color(0.8, 0.5, 1.0)
	if _flash > 0.0:
		c = Color(1, 1, 1)
	if _telegraph > 0.0:
		c = Color(1.0, 0.6, 0.3)   # avisa o ataque
	var fill := Color(c.r, c.g, c.b, 0.14)
	draw_rect(Rect2(-44, -40, 88, 70), fill, true)
	draw_rect(Rect2(-44, -40, 88, 70), c, false, 3.0)
	draw_rect(Rect2(-20, -60, 40, 22), fill, true)
	draw_rect(Rect2(-20, -60, 40, 22), c, false, 3.0)
	draw_circle(Vector2(0, -49), 6.0, Color(1, 0.4, 0.4))   # "olho"
	draw_line(Vector2(-30, 30), Vector2(-30, 48), c, 3.0)   # canhões
	draw_line(Vector2(30, 30), Vector2(30, 48), c, 3.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_telegraph = maxf(_telegraph - delta, 0.0)
	_atk = maxf(_atk - delta, 0.0)
	global_position.x = _home.x + sin(_t * 1.2) * 130.0
	global_position.y = _home.y + sin(_t * 2.3) * 16.0
	if _atk <= 0.0 and _telegraph <= 0.0:
		_telegraph = 0.45            # pisca antes de atirar (justo)
		_atk = 1.8 if pattern == 1 else 1.1
		await get_tree().create_timer(0.45).timeout
		if alive:
			if pattern >= 2 and _alt == 1:
				_side_volley()
			else:
				_drop_bombs()
			_alt = 1 - _alt
	queue_redraw()

func _drop_bombs() -> void:
	AudioManager.play("enemy_attack", 0.7)
	for i in range(-1, 2):
		var s := Shot.new()
		s.from_enemy = true
		s.vel = Vector2(i * 70.0, 210.0)
		get_parent().add_child(s)
		s.global_position = global_position + Vector2(i * 22.0, 34.0)

func _side_volley() -> void:
	AudioManager.play("enemy_attack", 0.7)
	var hero := get_tree().get_first_node_in_group("rhero")
	var dir := -1.0
	if hero and is_instance_valid(hero):
		dir = signf(hero.global_position.x - global_position.x)
	for a in [-0.22, 0.0, 0.22]:
		var s := Shot.new()
		s.from_enemy = true
		s.vel = Vector2(dir, 0.0).rotated(a) * 240.0
		get_parent().add_child(s)
		s.global_position = global_position + Vector2(dir * 30.0, 0.0)

func take_hit() -> void:
	if not alive:
		return
	hp -= 1
	_flash = 0.08
	AudioManager.play("hit", randf_range(0.85, 1.0))
	if hp <= 0:
		_die()

func _die() -> void:
	alive = false
	VFX.burst(global_position, get_parent(), Color(0.8, 0.5, 1.0), 44, 220.0, 90.0)
	VFX.burst(global_position, get_parent(), Color(1.0, 0.7, 0.3), 24, 150.0, 60.0)
	VFX.ring(global_position, get_parent(), Color(1.0, 0.6, 0.3, 0.85), 130.0, 0.6)
	AudioManager.play("fireball", 0.8)
	defeated.emit()
	queue_free()

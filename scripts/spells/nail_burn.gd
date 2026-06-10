extends Node
## Queimadura das Unhas de Lava — DoT universal anexado ao inimigo.
## Não edita os scripts dos inimigos: usa hp / is_dead / take_damage que todos
## expõem. Tica dano alguns instantes; o tick letal passa pelo take_damage normal
## (pra a morte/explosão acontecer pelo caminho padrão).

const DamageNumber := preload("res://scenes/effects/damage_number.tscn")

var dps: float = 8.0
var ticks: int = 4
var _interval := 0.5
var _t := 0.5
var _left := 0

func _ready() -> void:
	add_to_group("nail_burn")
	_left = ticks

func refresh() -> void:
	_left = ticks   # reacende a chama (não empilha)

func _process(delta: float) -> void:
	var e := get_parent()
	if e == null or not is_instance_valid(e) or e.is_dead:
		queue_free()
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = _interval
	_left -= 1
	var parent := e.get_parent()
	if parent != null:
		VFX.burst(e.global_position + Vector2(0, -12), parent, Color(1.0, 0.5, 0.12), 4, 34.0, 12.0)
	# Tint quente passageiro.
	if e.has_node("Sprite2D"):
		var s: Node = e.get_node("Sprite2D")
		s.modulate = Color(1.5, 0.7, 0.4)
	if e.hp - dps <= 0.0:
		e.take_damage(9999.0, e.global_position)   # morte pelo caminho normal
		queue_free()
		return
	e.hp -= dps
	if parent != null:
		var dn := DamageNumber.instantiate()
		parent.add_child(dn)
		dn.global_position = e.global_position + Vector2(randf_range(-8, 8), -26)
		dn.setup(dps, Color(1.0, 0.55, 0.18))
	if _left <= 0:
		if e.has_node("Sprite2D"):
			e.get_node("Sprite2D").modulate = Color.WHITE
		queue_free()

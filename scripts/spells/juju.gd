extends Area2D
## Juju — a fada aliada do CONVOKE.
## Voa pela tela por FLY_TIME (3s), vulnerável: cada hit conta; se levar MAIS de
## 2 hits, o efeito é CANCELADO. Sobrevivendo aos 3s, ela põe TODOS os inimigos
## (que tenham sleep()) pra dormir por SLEEP_DUR (10s) e sai de cena.

const FLY_TIME  := 3.0
const SLEEP_DUR := 10.0
const MAX_HITS  := 2          # o 3º hit (>2) corta o efeito

var _t := 0.0
var _hits := 0
var _iframe := 0.0
var _trail := 0.0
var _done := false
var _center: Vector2
var _spr: Sprite2D

func _ready() -> void:
	add_to_group("juju")
	_center = global_position
	_spr = Sprite2D.new()
	_spr.texture = SpriteSetup.get_texture("juju")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2.0, 2.0)
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new(); circ.radius = 12.0
	cs.shape = circ
	add_child(cs)
	monitoring = true
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)
	AudioManager.play("unlock", 1.2)
	VFX.sparkle(global_position, get_parent(), Color(0.70, 1.0, 0.60), 18)
	VFX.ring(global_position, get_parent(), Color(0.75, 1.0, 0.65, 0.8), 36.0, 0.4)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_iframe = maxf(_iframe - delta, 0.0)
	# Voo em lissajous ao redor do ponto de convocação (fica em cena, em risco).
	global_position = _center + Vector2(cos(_t * 2.3) * 150.0, sin(_t * 4.6) * 55.0 - 30.0)
	_spr.position.y = sin(_t * 18.0) * 1.5          # flutter das asas
	_spr.rotation = sin(_t * 2.3) * 0.15
	# blink de i-frame
	if _iframe > 0.0:
		_spr.modulate.a = 0.4 if fmod(_iframe, 0.12) > 0.06 else 1.0
	else:
		_spr.modulate.a = 1.0
	# trilha de fagulhas
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.06
		VFX.sparkle(global_position, get_parent(), Color(0.72, 1.0, 0.70), 2)
	if _t >= FLY_TIME:
		_do_sleep()

func _on_body(b: Node) -> void:
	if b.is_in_group("enemy"):
		_hit()

func _on_area(a: Node) -> void:
	if a.is_in_group("enemy_projectile"):
		_hit()
		if is_instance_valid(a):
			a.queue_free()

func _hit() -> void:
	if _iframe > 0.0 or _done:
		return
	_iframe = 0.4
	_hits += 1
	AudioManager.play("hit_player", 1.3)
	VFX.burst(global_position, get_parent(), Color(1.0, 0.6, 0.6), 8, 70.0, 20.0)
	_spr.modulate = Color(2.2, 1.2, 1.2)
	if _hits > MAX_HITS:
		_cancel()

func _do_sleep() -> void:
	if _done: return
	_done = true
	VFX.ring(global_position, get_parent(), Color(0.72, 1.0, 0.68, 0.9), 90.0, 0.5)
	VFX.burst(global_position, get_parent(), Color(0.72, 1.0, 0.68), 30, 130.0, 30.0)
	AudioManager.play("heal", 0.8)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead and e.has_method("sleep"):
			e.sleep(SLEEP_DUR)
	_leave()

func _cancel() -> void:
	if _done: return
	_done = true
	AudioManager.play("shield_break", 1.2)
	VFX.burst(global_position, get_parent(), Color(0.6, 0.6, 0.7), 16, 95.0, 30.0)
	# "!" de susto
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	lbl.position = Vector2(-4, -24)
	add_child(lbl)
	_leave()

func _leave() -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector2(0, -140), 0.7).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.7)
	tw.tween_callback(queue_free)

extends Node2D
## Mãe Rose — maga graduada de GELO (Convoke, lore/NG+). Paira por cima da Soph,
## canaliza e solta a Execução Aurora: uma cortina de aurora boreal que congela e
## estilhaça TODOS os inimigos. Por ser uma maga veterana (NG+), dá OVERKILL até
## no Boss.

const CHANNEL  := 0.7
const MOB_KILL := 99999.0

var facing: float = 1.0

var _spr: Sprite2D
var _started := false

func _ready() -> void:
	add_to_group("rose")
	_spr = Sprite2D.new()
	_spr.texture = SpriteSetup.get_texture("rose")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2.0, 2.0)
	_spr.position = Vector2(0, -26)
	_spr.flip_h = facing < 0
	_spr.modulate.a = 0.0
	add_child(_spr)

func _process(_d: float) -> void:
	if not _started:
		_started = true
		_run()

func _run() -> void:
	await _enter()
	if not is_instance_valid(self): return
	await _channel()
	if not is_instance_valid(self): return
	_unleash()
	await _leave()

func _enter() -> void:
	AudioManager.play("unlock", 0.9)
	_spr.position = Vector2(0, -44)
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(_spr, "position", Vector2(0, -26), 0.30).set_ease(Tween.EASE_OUT)
	VFX.sparkle(global_position + Vector2(0, -24), get_parent(), Color(0.6, 0.95, 1.0), 14)
	await tw.finished

func _channel() -> void:
	AudioManager.play("time_stop", 1.25)
	_spr.modulate = Color(0.7, 0.92, 1.3)
	# gelo convergindo
	var t := 0.0
	while t < CHANNEL and is_instance_valid(self):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		VFX.ring(global_position + Vector2(0, -22), get_parent(), Color(0.6, 0.95, 1.0, 0.5), 40.0 - t * 30.0, 0.2)
		VFX.sparkle(global_position + Vector2(randf_range(-30, 30), -22), get_parent(), Color(0.8, 1.0, 1.0), 3)
	_spr.modulate = Color.WHITE

func _unleash() -> void:
	AudioManager.play("time_stop", 0.7)
	AudioManager.play("missile_giant", 0.9)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and is_instance_valid(pl) and pl.has_method("shake"):
		pl.shake(14.0, 0.6)
	# Cortinas de aurora varrendo a arena.
	var base_x := global_position.x
	for i in range(-3, 5):
		var cur := Sprite2D.new()
		cur.texture = SpriteSetup.get_texture("rose_aurora")
		cur.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cur.scale = Vector2(2.2, 2.6)
		cur.modulate = Color(1, 1, 1, 0.0)
		get_parent().add_child(cur)
		cur.global_position = Vector2(base_x + i * 56.0, global_position.y - 30.0)
		var tw := cur.create_tween()
		tw.tween_interval(absi(i) * 0.04)
		tw.tween_property(cur, "modulate:a", 0.9, 0.12)
		tw.parallel().tween_property(cur, "position:y", cur.position.y + 24.0, 0.5)
		tw.tween_property(cur, "modulate:a", 0.0, 0.4)
		tw.tween_callback(cur.queue_free)
	# Congela e estilhaça TODOS os inimigos (overkill, inclusive boss).
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		var ep: Vector2 = e.global_position
		VFX.burst(ep + Vector2(0, -12), get_parent(), Color(0.7, 0.95, 1.0), 22, 150.0, 40.0)
		VFX.ring(ep + Vector2(0, -10), get_parent(), Color(0.8, 1.0, 1.0, 0.85), 40.0, 0.4)
		if e.has_node("Sprite2D"):
			e.get_node("Sprite2D").modulate = Color(0.6, 0.85, 1.4)
		e.take_damage(MOB_KILL, global_position)
	VFX.ring(global_position + Vector2(0, -10), get_parent(), Color(0.7, 0.95, 1.0, 0.8), 200.0, 0.6)

func _leave() -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self): return
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(0, -150), 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	await tw.finished

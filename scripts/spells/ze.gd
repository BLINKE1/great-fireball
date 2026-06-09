extends Node2D
## Pai Zé — mago de FOGO (Convoke, lore/NG+). Paira por cima da Soph, canaliza e
## solta a Grande Bola de Fogo: um meteoro flamejante que explode na arena e
## incinera TODOS os inimigos. Maga veterano (NG+) → OVERKILL até no Boss.
## (Amarra com o clímax "Great Fireball" do jogo.)

const CHANNEL  := 0.7
const MOB_KILL := 99999.0

var facing: float = 1.0

var _spr: Sprite2D
var _started := false

func _ready() -> void:
	add_to_group("ze")
	_spr = Sprite2D.new()
	_spr.texture = SpriteSetup.get_texture("ze")
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
	await _unleash()
	await _leave()

func _enter() -> void:
	AudioManager.play("unlock", 0.8)
	_spr.position = Vector2(0, -44)
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(_spr, "position", Vector2(0, -26), 0.30).set_ease(Tween.EASE_OUT)
	VFX.sparkle(global_position + Vector2(0, -24), get_parent(), Color(1.0, 0.6, 0.2), 14)
	await tw.finished

func _channel() -> void:
	AudioManager.play("burn", 0.8)
	_spr.modulate = Color(1.4, 0.9, 0.7)
	var t := 0.0
	while t < CHANNEL and is_instance_valid(self):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		VFX.ring(global_position + Vector2(0, -22), get_parent(), Color(1.0, 0.6, 0.15, 0.5), 40.0 - t * 30.0, 0.2)
		VFX.sparkle(global_position + Vector2(randf_range(-26, 26), -22), get_parent(), Color(1.0, 0.7, 0.3), 3)
	_spr.modulate = Color.WHITE

func _unleash() -> void:
	# Centro do alvo: média dos inimigos (ou à frente da Soph se não houver).
	var center := global_position + Vector2(facing * 120.0, 0.0)
	var en := _alive_enemies()
	if not en.is_empty():
		var sum := Vector2.ZERO
		for e in en:
			sum += e.global_position
		center = sum / en.size()
	# Grande Bola de Fogo descendo do alto.
	var fb := Sprite2D.new()
	fb.texture = SpriteSetup.get_texture("ze_fireball")
	fb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fb.scale = Vector2(2.0, 2.0)
	get_parent().add_child(fb)
	fb.global_position = global_position + Vector2(0, -40)
	AudioManager.play("missile_giant", 0.7)
	var tw := fb.create_tween()
	tw.tween_property(fb, "global_position", center + Vector2(0, -8), 0.34).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fb, "scale", Vector2(6.0, 6.0), 0.34)
	tw.parallel().tween_property(fb, "rotation", 4.0, 0.34)
	await tw.finished
	if is_instance_valid(fb):
		fb.queue_free()
	# EXPLOSÃO: incinera tudo (overkill, inclusive boss).
	AudioManager.play("fireball", 1.0)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and is_instance_valid(pl) and pl.has_method("shake"):
		pl.shake(22.0, 0.8)
	VFX.burst(center, get_parent(), Color(1.0, 0.7, 0.2), 60, 280.0, 120.0)
	VFX.burst(center, get_parent(), Color(1.0, 0.35, 0.08), 36, 200.0, 80.0)
	VFX.ring(center, get_parent(), Color(1.0, 0.6, 0.15, 0.9), 120.0, 0.5)
	VFX.ring(center, get_parent(), Color(1.0, 0.4, 0.1, 0.7), 200.0, 0.7)
	VFX.ground_burst(center + Vector2(0, 30), get_parent(), Color(0.8, 0.4, 0.12), 30)
	for e in _alive_enemies():
		VFX.burst(e.global_position + Vector2(0, -12), get_parent(), Color(1.0, 0.6, 0.2), 18, 150.0, 40.0)
		if e.has_node("Sprite2D"):
			e.get_node("Sprite2D").modulate = Color(2.0, 1.2, 0.4)
		e.take_damage(MOB_KILL, center)
	await get_tree().create_timer(0.1).timeout

func _alive_enemies() -> Array:
	var r: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead:
			r.append(e)
	return r

func _leave() -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self): return
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(0, -150), 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	await tw.finished

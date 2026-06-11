extends Node2D
## Di — a elfa Sentinela, esposa do Gus, aliada do Convoke.
## Arqueira élfica de alcance: surge ao alto/atrás da Soph, MARCA todos os
## inimigos e despeja uma CHUVA DE FLECHAS por VOLLEY_TIME, priorizando os mais
## feridos (finaliza mobs em baixa) e cravando chip no Boss com tiros perfurantes.
## Se o Gus estiver em campo, ela entra "em dupla" (cadência maior) — o casal.
##
## Princípio de equilíbrio (como Gus/Will): sozinha NÃO mata um Boss cheio.

const ENTER_TIME    := 0.30
# Di NÍVEL 1: chuva curta (metade das flechadas) — estava overkill. A versão
# longa (VOLLEY_TIME 4.0) fica reservada pra evolução "Convoke nível 2".
const VOLLEY_TIME   := 2.0
const FIRE_INTERVAL := 0.16
const ARROW_FLY     := 0.14
const DI_ARROW_MOB  := 30.0
const DI_ARROW_BOSS := 7.0
const MULTI_EVERY   := 4         # a cada N tiros, um multishot (até 3 alvos)

var facing: float = 1.0

var _spr: Sprite2D
var _origin: Vector2
var _base_y := -26.0
var _started := false
var _hovering := false
var _leaving := false
var _hover_t := 0.0

func _ready() -> void:
	add_to_group("di")
	_origin = global_position
	_spr = Sprite2D.new()
	_spr.texture = SpriteSetup.get_texture("di")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2.0, 2.0)
	_spr.position = Vector2(0, _base_y)
	_spr.flip_h = facing < 0
	_spr.modulate.a = 0.0
	add_child(_spr)

func _process(delta: float) -> void:
	if not _started:
		_started = true
		_origin = global_position
		_run()
	_hover_t += delta
	if _hovering and not _leaving and is_instance_valid(_spr):
		_spr.position.y = _base_y + sin(_hover_t * 3.0) * 2.0

# ── Sequência ────────────────────────────────────────────────────────────────
func _run() -> void:
	await _enter()
	if not is_instance_valid(self): return
	_mark_all()
	var tandem: bool = get_tree().get_first_node_in_group("gus") != null
	if tandem:
		_label("EM DUPLA! ♥", Color(1.0, 0.6, 0.7))
	await _volley(tandem)
	if is_instance_valid(self):
		await _leave()

func _enter() -> void:
	AudioManager.play("unlock", 1.25)
	_spr.position = Vector2(-facing * 16, _base_y - 14)
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 1.0, ENTER_TIME * 0.6)
	tw.parallel().tween_property(_spr, "position", Vector2(0, _base_y), ENTER_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	VFX.sparkle(global_position + Vector2(0, -22), get_parent(), Color(0.6, 1.0, 0.7), 14)
	await tw.finished
	_hovering = true

func _mark_all() -> void:
	for e in _alive_enemies():
		VFX.ring(e.global_position + Vector2(0, -12), get_parent(), Color(0.6, 1.0, 0.7, 0.8), 22.0, 0.4)
	AudioManager.play("detect", 1.2)

func _volley(tandem: bool) -> void:
	var interval := FIRE_INTERVAL * (0.78 if tandem else 1.0)
	var shots := int(VOLLEY_TIME / interval)
	for i in shots:
		if not is_instance_valid(self): return
		if _alive_enemies().is_empty():
			break
		if i % MULTI_EVERY == 0:
			_multishot()
		else:
			var tgt := _pick_target()
			if tgt:
				_fire_arrow(tgt)
		await _wait(interval)

# ── Tiro ─────────────────────────────────────────────────────────────────────
func _fire_arrow(target: Node) -> void:
	if not is_instance_valid(target):
		return
	# Recuo do arco.
	var pop := _spr.create_tween()
	pop.tween_property(_spr, "scale", Vector2(1.85, 2.1), 0.04)
	pop.tween_property(_spr, "scale", Vector2(2.0, 2.0), 0.08)
	AudioManager.play("arrow", randf_range(1.05, 1.2))
	var tpos: Vector2 = target.global_position + Vector2(0, -14)
	var arrow := Sprite2D.new()
	arrow.texture = SpriteSetup.get_texture("di_arrow")
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.scale = Vector2(2.0, 2.0)
	get_parent().add_child(arrow)
	arrow.global_position = _origin + Vector2(facing * 16, -20)
	arrow.rotation = (tpos - arrow.global_position).angle()
	var is_boss: bool = target.is_in_group("boss")
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "global_position", tpos, ARROW_FLY)
	tw.tween_callback(_arrow_hit.bind(arrow, target, is_boss, tpos))

func _arrow_hit(arrow: Node, target: Node, is_boss: bool, tpos: Vector2) -> void:
	if is_instance_valid(arrow):
		arrow.queue_free()
	if not is_instance_valid(target) or target.is_dead:
		VFX.sparkle(tpos, get_parent(), Color(0.6, 1.0, 0.7), 3)
		return
	if is_boss:
		VFX.hit_spark(tpos, get_parent(), facing)
		VFX.burst(tpos, get_parent(), Color(0.7, 1.0, 0.6), 5, 50.0, 14.0)
		target.take_damage(DI_ARROW_BOSS, _origin)
	else:
		var lethal: bool = target.hp <= DI_ARROW_MOB
		target.take_damage(DI_ARROW_MOB, _origin)
		if lethal:
			VFX.burst(tpos, get_parent(), Color(0.5, 1.0, 0.6), 16, 120.0, 36.0)
			VFX.ring(tpos, get_parent(), Color(0.6, 1.0, 0.7, 0.7), 26.0, 0.25)
		else:
			VFX.hit_spark(tpos, get_parent(), facing)

func _multishot() -> void:
	var en := _alive_enemies()
	if en.is_empty():
		return
	en.sort_custom(func(a, b): return a.hp < b.hp)
	var n: int = mini(3, en.size())
	for i in n:
		_fire_arrow(en[i])
	if n > 1:
		AudioManager.play("missile_spread", 0.95)

# ── Saída ────────────────────────────────────────────────────────────────────
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play("dash", 1.15)
	VFX.sparkle(global_position + Vector2(0, -20), get_parent(), Color(0.6, 1.0, 0.7), 12)
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(facing * 8, _base_y - 6), 0.10)
	tw.tween_property(_spr, "position", Vector2(facing * 44, -160), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_spr, "rotation", facing * 4.0, 0.5)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	await tw.finished

# ── Helpers ──────────────────────────────────────────────────────────────────
func _alive_enemies() -> Array:
	var r: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead:
			r.append(e)
	return r

func _pick_target() -> Node:
	var mobs: Array = []
	var boss: Node = null
	for e in _alive_enemies():
		if e.is_in_group("boss"):
			if boss == null: boss = e
		else:
			mobs.append(e)
	if not mobs.is_empty():
		mobs.sort_custom(func(a, b): return a.hp < b.hp)
		return mobs[0]
	return boss

func _label(txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = Vector2(-12, -54)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.14)
	tw.tween_interval(0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

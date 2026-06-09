extends Node2D
## Gui Fenrir — aliado do Convoke. Entra num RUSH de espadão e faz um "espetinho"
## de até 3 mobs (hit-kill em linha) OU crava a espada num Boss (dano alto, não
## mata). Em seguida se TRANSFORMA EM LOBISOMEM, ataca com ferocidade (dilacera o
## Boss ou os mobs restantes) e vai embora com um uivo.
##
## Equilíbrio (como os outros): sozinho NÃO mata um Boss cheio
## (estocada 40 + ferocidade 90 = 130 < 280).

const ENTER_TIME   := 0.28
const RUSH_TIME    := 0.24
const SKEWER_MAX   := 3
const STAB_DMG     := 40.0
const WOLF_SWIPES  := 5
const WOLF_SWIPE   := 12.0
const WOLF_BITE    := 30.0
const MOB_KILL     := 99999.0

var facing: float = 1.0

var _spr: Sprite2D
var _blade: Sprite2D = null
var _started := false

func _ready() -> void:
	add_to_group("gui_fenrir")
	_spr = Sprite2D.new()
	_spr.texture = SpriteSetup.get_texture("gui")
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

# ── Sequência ────────────────────────────────────────────────────────────────
func _run() -> void:
	await _enter()
	if not is_instance_valid(self): return
	var skewer := _skewer_targets()
	var boss := _first_boss()
	var stab_boss: bool = skewer.is_empty() and boss != null
	await _rush(skewer, boss, stab_boss)
	if not is_instance_valid(self): return
	await _transform()
	if not is_instance_valid(self): return
	await _ferocity()
	if is_instance_valid(self):
		await _leave()

func _enter() -> void:
	AudioManager.play("dash", 0.95)
	_spr.position = Vector2(-facing * 22, -26)
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 1.0, ENTER_TIME * 0.6)
	tw.parallel().tween_property(_spr, "position", Vector2(0, -26), ENTER_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tw.finished

# ── RUSH / espetinho ─────────────────────────────────────────────────────────
func _rush(skewer: Array, boss: Node, stab_boss: bool) -> void:
	_face_enemies()
	AudioManager.play("sword", 0.8)
	AudioManager.play("dash", 1.05)
	# Espadão estendido à frente durante a investida.
	_blade = Sprite2D.new()
	_blade.texture = SpriteSetup.get_texture("gui_sword")
	_blade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blade.scale = Vector2(2.0, 2.0)
	_blade.flip_h = facing < 0
	_blade.position = Vector2(facing * 34, -18)
	add_child(_blade)

	var endp: Vector2
	if stab_boss and is_instance_valid(boss):
		endp = boss.global_position - Vector2(facing * 42, 0)
	elif not skewer.is_empty():
		var far: Node = skewer[skewer.size() - 1]
		var fp: Vector2 = far.global_position if is_instance_valid(far) else global_position
		endp = fp + Vector2(facing * 28, 0)
	else:
		endp = global_position + Vector2(facing * 130, 0)

	VFX.sparkle(global_position + Vector2(0, -18), get_parent(), Color(0.85, 0.88, 0.95), 8)
	var tw := create_tween()
	tw.tween_property(self, "global_position", endp, RUSH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tw.finished

	# Espeta os mobs em sequência (o "espetinho").
	for m in skewer:
		if is_instance_valid(m) and not m.is_dead:
			VFX.hit_spark(m.global_position + Vector2(0, -12), get_parent(), facing)
			VFX.burst(m.global_position + Vector2(0, -12), get_parent(), Color(0.92, 0.86, 0.70), 14, 110.0, 34.0)
			m.take_damage(MOB_KILL, global_position)
		await _wait(0.06)
	if not skewer.is_empty():
		_label("ESPETINHO!", Color(1.0, 0.85, 0.4))
		_pl_shake(7.0, 0.3)

	# Ou crava no Boss.
	if stab_boss and is_instance_valid(boss) and not boss.is_dead:
		VFX.hit_spark(boss.global_position + Vector2(facing * 14, -12), get_parent(), facing)
		VFX.burst(boss.global_position + Vector2(facing * 10, -12), get_parent(), Color(0.85, 0.9, 1.0), 22, 150.0, 40.0)
		VFX.ring(boss.global_position + Vector2(0, -10), get_parent(), Color(0.8, 0.9, 1.0, 0.8), 40.0, 0.35)
		boss.take_damage(STAB_DMG, global_position)
		_label("CRAVOU!", Color(1.0, 0.6, 0.3))
		_pl_shake(10.0, 0.35)
	await _wait(0.1)

# ── Transformação ────────────────────────────────────────────────────────────
func _transform() -> void:
	AudioManager.play("roar", 0.7)
	_pl_shake(12.0, 0.5)
	if is_instance_valid(_blade):
		_blade.queue_free(); _blade = null
	VFX.burst(global_position + Vector2(0, -22), get_parent(), Color(0.6, 0.58, 0.55), 24, 130.0, 30.0)
	VFX.ring(global_position + Vector2(0, -18), get_parent(), Color(0.8, 0.75, 0.3, 0.8), 50.0, 0.4)
	var tw := _spr.create_tween()
	tw.tween_property(_spr, "scale", Vector2(2.5, 2.5), 0.12)
	tw.parallel().tween_property(_spr, "modulate", Color(2.0, 2.0, 2.0), 0.10)
	await tw.finished
	if not is_instance_valid(self): return
	_spr.texture = SpriteSetup.get_texture("gui_wolf")
	_spr.position = Vector2(0, -30)
	_spr.scale = Vector2(2.2, 2.2)
	_spr.modulate = Color.WHITE
	_label("FENRIR!", Color(0.95, 0.8, 0.2))
	await _wait(0.12)

# ── Ferocidade (forma lobo) ──────────────────────────────────────────────────
func _ferocity() -> void:
	var boss := _first_boss()
	if boss and is_instance_valid(boss):
		await _maul_boss(boss)
	else:
		for i in 4:
			var m := _nearest_mob()
			if m == null:
				break
			await _dash_to(m.global_position - Vector2(facing * 20, 0))
			_face_enemies()
			if is_instance_valid(m) and not m.is_dead:
				VFX.hit_spark(m.global_position + Vector2(0, -12), get_parent(), facing)
				VFX.burst(m.global_position + Vector2(0, -12), get_parent(), Color(0.9, 0.85, 0.6), 16, 120.0, 36.0)
				AudioManager.play("enemy_attack", randf_range(0.7, 0.85))
				m.take_damage(MOB_KILL, global_position)
			await _wait(0.12)

func _maul_boss(boss: Node) -> void:
	await _dash_to(boss.global_position - Vector2(facing * 30, 0))
	_face_enemies()
	AudioManager.play("roar", 0.9)
	for i in WOLF_SWIPES:
		if not is_instance_valid(boss) or boss.is_dead:
			break
		var sd := facing if i % 2 == 0 else -facing
		VFX.hit_spark(boss.global_position + Vector2(facing * 12, -12), get_parent(), sd)
		VFX.burst(boss.global_position + Vector2(facing * 8, -10), get_parent(), Color(0.85, 0.85, 0.9), 6, 70.0, 16.0)
		AudioManager.play("enemy_attack", randf_range(0.7, 0.9))
		boss.take_damage(WOLF_SWIPE, global_position)
		_spr.position.x = sin(float(i) * 2.0) * 4.0
		await _wait(0.12)
	_spr.position.x = 0.0
	if is_instance_valid(boss) and not boss.is_dead:
		_label("DILACEROU!", Color(1.0, 0.4, 0.3))
		AudioManager.play("enemy_die", 0.8)
		_pl_shake(16.0, 0.5)
		VFX.burst(boss.global_position + Vector2(facing * 16, -10), get_parent(), Color(0.85, 0.85, 0.9), 26, 170.0, 50.0)
		VFX.ring(boss.global_position + Vector2(0, -10), get_parent(), Color(0.9, 0.5, 0.3, 0.8), 56.0, 0.4)
		boss.take_damage(WOLF_BITE, global_position)
	await _wait(0.2)

# ── Saída (uivo + salto) ─────────────────────────────────────────────────────
func _leave() -> void:
	AudioManager.play("roar", 1.15)
	VFX.sparkle(global_position + Vector2(0, -24), get_parent(), Color(0.8, 0.78, 0.7), 12)
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(-facing * 10, -22), 0.10)
	tw.tween_property(_spr, "position", Vector2(facing * 150, -170), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_spr, "rotation", facing * 3.0, 0.5)
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

func _mobs_by_dist() -> Array:
	var mobs: Array = []
	for e in _alive_enemies():
		if not e.is_in_group("boss"):
			mobs.append(e)
	mobs.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return mobs

func _skewer_targets() -> Array:
	var mobs := _mobs_by_dist()
	return mobs.slice(0, mini(SKEWER_MAX, mobs.size()))

func _first_boss() -> Node:
	for e in _alive_enemies():
		if e.is_in_group("boss"):
			return e
	return null

func _nearest_mob() -> Node:
	var mobs := _mobs_by_dist()
	return mobs[0] if not mobs.is_empty() else null

func _face_enemies() -> void:
	var en := _alive_enemies()
	if en.is_empty():
		return
	var nearest: Node = en[0]
	for e in en:
		if global_position.distance_to(e.global_position) < global_position.distance_to(nearest.global_position):
			nearest = e
	var d := signf(nearest.global_position.x - global_position.x)
	if d != 0.0:
		facing = d
		_spr.flip_h = facing < 0

func _dash_to(world: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", world, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	VFX.sparkle(global_position + Vector2(0, -18), get_parent(), Color(0.8, 0.78, 0.72), 5)
	await tw.finished

func _pl_shake(amount: float, dur: float) -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl and is_instance_valid(pl) and pl.has_method("shake"):
		pl.shake(amount, dur)

func _label(txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = Vector2(-12, -56)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.14)
	tw.tween_interval(0.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

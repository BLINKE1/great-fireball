extends Node2D
## Gus — o aliado DAGGER/AVENTUREIRO do Convoke (inspirado nos Adventurer de
## Lineage II e no Gustavo, irmão do Will, que luta jiu-jítsu). Ágil e forte,
## NÃO é um ladino: é um lutador de adagas.
##
## Vem por trás da Soph com duas adagas e ALOCA os alvos assim:
##   - As adagas vão nos mobs mais próximos (hit-kill). Adaga que sobra vai no
##     Boss (dá dano, não mata).
##   - 3+ mobs  → adaga, adaga, e finaliza o 3º no jiu-jítsu (NÃO chega no Boss).
##   - 2 mobs+Boss → mata os dois (uma adaga cada) e arranca o braço do Boss.
##   - 1 mob+Boss  → mata o mob, joga a outra adaga no Boss e arranca o braço.
##   - só Boss     → as duas adagas no Boss + arranca o braço.
## Os 3 danos somados NÃO matam um Boss cheio (22+22+55 = 99 < 280).

const ENTER_TIME     := 0.30
const DAGGER_FLY     := 0.16
const DASH_TIME      := 0.16
const CLING_TIME     := 3.0
const MOB_KILL_DMG   := 99999.0
const DAGGER_BOSS_DMG:= 22.0
const ARM_RIP_DMG    := 55.0

const DaggerTex := "gus_dagger"

var facing: float = 1.0

var _spr: Sprite2D
var _started := false
var _leaving := false

func _ready() -> void:
	add_to_group("gus")
	_spr = Sprite2D.new()
	_spr.texture = SpriteSetup.get_texture("gus")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2.0, 2.0)
	_spr.position = Vector2(0, -26)
	_spr.flip_h = facing < 0
	_spr.modulate.a = 0.0
	add_child(_spr)

func _process(_d: float) -> void:
	if not _started:
		_started = true
		_run()   # coroutine

# ── Sequência principal ───────────────────────────────────────────────────────
func _run() -> void:
	await _enter()
	if not is_instance_valid(self): return
	var plan := _build_plan()
	for step in plan:
		if not is_instance_valid(self): return
		match step["type"]:
			"dagger_kill": await _do_dagger(step["target"], false)
			"dagger_boss": await _do_dagger(step["target"], true)
			"finish_mob":  await _do_finish_mob(step["target"])
			"finish_boss": await _do_finish_boss(step["target"])
	if is_instance_valid(self):
		await _leave()

func _build_plan() -> Array:
	var mobs: Array = []
	var boss: Node = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if e.is_in_group("boss"):
			if boss == null: boss = e
		else:
			mobs.append(e)
	mobs.sort_custom(func(a, b): return _dist(a) < _dist(b))

	var plan: Array = []
	var daggers := 2
	var mi := 0
	# Adagas nos mobs mais próximos (hit-kill).
	while daggers > 0 and mi < mobs.size():
		plan.append({"type": "dagger_kill", "target": mobs[mi]})
		daggers -= 1
		mi += 1
	if mobs.size() >= 3:
		# Três (ou mais) mobs: finaliza o 3º no jiu-jítsu e NÃO chega no Boss.
		plan.append({"type": "finish_mob", "target": mobs[2]})
	else:
		# Sobrou adaga? Vai no Boss. Depois arranca o braço.
		while daggers > 0 and boss != null:
			plan.append({"type": "dagger_boss", "target": boss})
			daggers -= 1
		if boss != null:
			plan.append({"type": "finish_boss", "target": boss})
		elif mi < mobs.size():
			# Sem Boss e ainda tem mob (caso raro): finaliza ele.
			plan.append({"type": "finish_mob", "target": mobs[mi]})
	return plan

func _dist(e: Node) -> float:
	return global_position.distance_to(e.global_position)

# ── Entrada (por trás da Soph) ────────────────────────────────────────────────
func _enter() -> void:
	AudioManager.play("dash", 1.1)
	_spr.position = Vector2(-facing * 26, -26)
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 1.0, ENTER_TIME * 0.6)
	tw.parallel().tween_property(_spr, "position", Vector2(0, -26), ENTER_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	VFX.sparkle(global_position + Vector2(0, -20), get_parent(), Color(0.5, 0.9, 0.8), 10)
	await tw.finished

# ── Adaga arremessada ─────────────────────────────────────────────────────────
func _do_dagger(target: Node, is_boss: bool) -> void:
	if not is_instance_valid(target):
		return
	_face_to(target)
	# Pose de arremesso (pequeno recuo + estica).
	var pop := _spr.create_tween()
	pop.tween_property(_spr, "scale", Vector2(2.2, 1.8), 0.05)
	pop.tween_property(_spr, "scale", Vector2(2.0, 2.0), 0.10)
	AudioManager.play("sword", randf_range(1.1, 1.25))
	var tpos: Vector2 = target.global_position + Vector2(0, -16)
	var dag := Sprite2D.new()
	dag.texture = SpriteSetup.get_texture(DaggerTex)
	dag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dag.scale = Vector2(2.0, 2.0)
	get_parent().add_child(dag)
	dag.global_position = global_position + Vector2(facing * 14, -20)
	dag.rotation = (tpos - dag.global_position).angle()
	var tw := dag.create_tween()
	tw.tween_property(dag, "global_position", tpos, DAGGER_FLY)
	await tw.finished
	if is_instance_valid(dag):
		dag.queue_free()
	if is_instance_valid(target):
		if is_boss:
			VFX.hit_spark(tpos, get_parent(), facing)
			VFX.burst(tpos, get_parent(), Color(0.85, 0.9, 1.0), 8, 80.0, 20.0)
			target.take_damage(DAGGER_BOSS_DMG, global_position)
		else:
			_kill_vfx(tpos, Color(0.85, 0.9, 1.0))
			target.take_damage(MOB_KILL_DMG, global_position)
	await _wait(0.10)

# ── Finalização de jiu-jítsu (mob) ────────────────────────────────────────────
func _do_finish_mob(target: Node) -> void:
	if not is_instance_valid(target):
		return
	_face_to(target)
	var dest: Vector2 = target.global_position - Vector2(facing * 20, 0)
	await _dash_to(dest)
	if not is_instance_valid(target):
		return
	AudioManager.play("dash", 0.9)
	# Pega o alvo: flurry + giro (a "luta").
	for i in 3:
		if not is_instance_valid(target): break
		VFX.hit_spark(target.global_position + Vector2(0, -14), get_parent(), -facing if i % 2 else facing)
		AudioManager.play("hit", randf_range(0.95, 1.1))
		if target.has_method("get") and is_instance_valid(target.get_node_or_null("Sprite2D")):
			target.get_node("Sprite2D").rotation = randf_range(-0.5, 0.5)
		_spr.position.x = (target.global_position.x - global_position.x) * 0.4 + sin(float(i) * 3.0) * 4.0
		await _wait(0.11)
	# Finaliza (jiu-jítsu): estoura o alvo.
	if is_instance_valid(target):
		_label("FINALIZADO!", Color(1.0, 0.85, 0.3))
		_kill_vfx(target.global_position + Vector2(0, -12), Color(0.4, 0.9, 0.5))
		var pl := get_tree().get_first_node_in_group("player")
		if pl and is_instance_valid(pl) and pl.has_method("shake"):
			pl.shake(8.0, 0.3)
		target.take_damage(MOB_KILL_DMG, global_position)
	_spr.position.x = 0.0
	await _wait(0.18)

# ── Arrancada do braço (Boss) ─────────────────────────────────────────────────
func _do_finish_boss(target: Node) -> void:
	if not is_instance_valid(target):
		return
	_face_to(target)
	var grab_off := Vector2(facing * 34, -10)
	await _dash_to(target.global_position + grab_off)
	if not is_instance_valid(target) or target.is_dead:
		return
	AudioManager.play("roar", 1.0)
	_label("SEGUROU!", Color(0.6, 1.0, 0.7))
	# Gruda no braço por CLING_TIME, seguindo o boss e forçando (tensão).
	var t := 0.0
	var strain := 0.0
	while t < CLING_TIME and is_instance_valid(target) and not target.is_dead:
		await get_tree().physics_frame
		if not is_instance_valid(self): return
		t += get_physics_process_delta_time()
		if is_instance_valid(target):
			global_position = target.global_position + grab_off
		# tremor crescente da força
		var s := 1.0 + t / CLING_TIME * 3.0
		_spr.position = Vector2(randf_range(-s, s), -26 + randf_range(-s, s))
		strain -= get_physics_process_delta_time()
		if strain <= 0.0:
			strain = 0.18
			VFX.burst(global_position + Vector2(0, -14), get_parent(), Color(0.6, 0.3, 0.55), 4, 40.0, 12.0)
	_spr.position = Vector2(0, -26)
	# ARRANCA: dano grande + braço voando + tremor.
	if is_instance_valid(target) and not target.is_dead:
		_label("Agora esse braço é meu!", Color(1.0, 0.55, 0.35))
		AudioManager.play("enemy_die", 0.8)
		var pl := get_tree().get_first_node_in_group("player")
		if pl and is_instance_valid(pl) and pl.has_method("shake"):
			pl.shake(18.0, 0.6)
		VFX.burst(target.global_position + Vector2(facing * 20, -10), get_parent(), Color(0.4, 0.7, 0.2), 30, 200.0, 60.0)
		VFX.burst(target.global_position + Vector2(facing * 20, -10), get_parent(), Color(0.6, 0.2, 0.5), 16, 140.0, 40.0)
		VFX.ring(target.global_position + Vector2(0, -10), get_parent(), Color(0.7, 0.3, 0.3, 0.8), 60.0, 0.4)
		# O Boss FICA SEM O BRAÇO de verdade (troca o sprite).
		if target.has_method("lose_arm"):
			target.lose_arm()
		_fling_arm(target.global_position + Vector2(facing * 26, -12))
		target.take_damage(ARM_RIP_DMG, global_position)
	await _wait(0.22)

func _fling_arm(from: Vector2) -> void:
	var arm := Sprite2D.new()
	arm.texture = SpriteSetup.get_texture("mutant_arm")
	arm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm.scale = Vector2(2.0, 2.0)
	arm.flip_h = facing < 0
	get_parent().add_child(arm)
	arm.global_position = from
	var tw := arm.create_tween()
	tw.tween_property(arm, "global_position", from + Vector2(facing * 120, -40), 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(arm, "global_position:y", from.y + 120, 0.7).set_delay(0.0)
	tw.parallel().tween_property(arm, "rotation", facing * 6.0, 0.7)
	tw.tween_property(arm, "modulate:a", 0.0, 0.2)
	tw.tween_callback(arm.queue_free)

# ── Saída (salto pra fora) ────────────────────────────────────────────────────
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play("dash", 1.05)
	VFX.sparkle(global_position + Vector2(0, -20), get_parent(), Color(0.5, 0.9, 0.8), 12)
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(-facing * 8, -34), 0.10)
	tw.tween_property(_spr, "position", Vector2(facing * 130, -120), 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_spr, "rotation", facing * 8.0, 0.45)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)
	await tw.finished

# ── Helpers ───────────────────────────────────────────────────────────────────
func _dash_to(world: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", world, DASH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# rastro de velocidade
	VFX.sparkle(global_position + Vector2(0, -18), get_parent(), Color(0.5, 0.9, 0.8), 6)
	await tw.finished

func _face_to(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var d := signf(target.global_position.x - global_position.x)
	if d != 0.0:
		facing = d
		_spr.flip_h = facing < 0

func _kill_vfx(pos: Vector2, col: Color) -> void:
	VFX.hit_spark(pos, get_parent(), facing)
	VFX.burst(pos, get_parent(), col, 16, 130.0, 40.0)
	VFX.ring(pos, get_parent(), Color(col.r, col.g, col.b, 0.7), 28.0, 0.25)
	AudioManager.play("enemy_die", randf_range(0.95, 1.1))

func _label(txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = Vector2(-10, -52)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.14)
	tw.tween_interval(0.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

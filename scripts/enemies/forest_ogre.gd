extends CharacterBody2D

enum Phase { ONE, TWO, THREE }

const MAX_HP          = 350.0
const SPEED_WALK      = 38.0
const SPEED_CHARGE    = 200.0
const GRAVITY         = 980.0
const DETECT_RANGE    = 450.0
const STOMP_RANGE     = 65.0
const STOMP_DAMAGE    = 35.0
const MELEE_DAMAGE    = 40.0
const KNOCKBACK_DECAY = 500.0
const CHARGE_COOLDOWN = 3.5
const STOMP_COOLDOWN  = 4.0
const CHARGE_WINDUP   = 0.4

const DamageNumber  = preload("res://scenes/effects/damage_number.tscn")
const GoblinScene   = preload("res://scenes/enemies/goblin.tscn")
const OgreShockwave = preload("res://scenes/enemies/ogre_shockwave.tscn")

@onready var hp_bar = $HPBar
@onready var sprite = $Sprite2D

signal boss_hp_changed(ratio: float)
signal boss_died

var hp: float = MAX_HP
var phase: Phase = Phase.ONE
var facing: float = -1.0
var is_dead: bool = false
var is_charging: bool = false
var is_winding_up: bool = false
var knockback: Vector2 = Vector2.ZERO
var player: Node = null
var charge_timer: float = 1.2
var stomp_timer: float = 0.0
var phase2_triggered: bool = false
var phase3_triggered: bool = false
var _alerted: bool = false

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	var tex := SpriteSetup.get_texture("forest_ogre")
	if tex:
		sprite.texture = tex
		sprite.modulate = Color.WHITE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	GameState.time_stop_started.connect(_on_time_stop)
	GameState.time_stop_ended.connect(_on_time_resume)
	boss_hp_changed.emit(1.0)

func _physics_process(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if is_dead or GameState.time_stopped:
		if knockback.length() > 0.0:
			velocity = knockback
			move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if knockback.length() > 80.0:
		velocity.x = knockback.x
		move_and_slide()
		return

	charge_timer = max(charge_timer - delta, 0.0)
	stomp_timer  = max(stomp_timer  - delta, 0.0)

	_tick_ai()
	move_and_slide()

func _tick_ai() -> void:
	if not player or not is_instance_valid(player): return

	var dist = global_position.distance_to(player.global_position)
	var dir  = sign(player.global_position.x - global_position.x)

	if dist > DETECT_RANGE:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK * 4.0)
		return

	if not _alerted:
		_alerted = true
		_show_alert()

	facing = dir if dir != 0 else facing
	sprite.flip_h = facing < 0

	if is_winding_up:
		velocity.x = 0.0
		return

	if is_charging:
		velocity.x = facing * SPEED_CHARGE
		# Cancel charge if we hit a wall or overshoot by a lot
		if is_on_wall():
			is_charging = false
			velocity.x = 0.0
		return

	# Stomp when player is very close
	if dist < STOMP_RANGE and stomp_timer <= 0.0:
		_do_stomp()
		return

	# Start charge at medium range
	if dist < 350.0 and charge_timer <= 0.0:
		_start_charge()
		return

	# Normal walk toward player
	var speed = SPEED_WALK * (1.6 if phase == Phase.THREE else 1.0)
	velocity.x = dir * speed

func _on_time_stop() -> void:
	if is_dead: return
	sprite.create_tween().tween_property(sprite, "modulate", Color(0.55, 0.72, 1.20), 0.14)

func _on_time_resume() -> void:
	if is_dead: return
	sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _show_alert() -> void:
	AudioManager.play("detect")
	var lbl := Label.new()
	lbl.text = "!!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.50, 0.08))
	lbl.position = Vector2(-10, -88)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(2.0, 2.0), 0.10)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.20)
	tw.tween_interval(0.45)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.30)
	tw.tween_callback(lbl.queue_free)

func _start_charge() -> void:
	charge_timer = CHARGE_COOLDOWN
	is_winding_up = true
	velocity.x = 0.0
	AudioManager.play("stomp")
	sprite.modulate = Color(2.0, 0.65, 0.45)   # telegrafia: brilho vermelho = vai investir!
	# Scale up briefly as windup visual
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.88), CHARGE_WINDUP * 0.5)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), CHARGE_WINDUP * 0.5)
	await get_tree().create_timer(CHARGE_WINDUP).timeout
	if is_dead or not is_instance_valid(self): return
	is_winding_up = false
	is_charging = true
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.55).timeout
	if is_instance_valid(self) and not is_dead:
		is_charging = false
		# Check if player was hit during charge
		if player and is_instance_valid(player):
			var d = global_position.distance_to(player.global_position)
			if d < 60.0:
				player.take_damage(MELEE_DAMAGE, global_position)

func _do_stomp() -> void:
	stomp_timer = STOMP_COOLDOWN
	is_charging = false
	velocity.x = 0.0
	AudioManager.play("stomp")
	if player and is_instance_valid(player):
		player.shake(12.0, 0.5)

	# Scale squash + flash quente no impacto do pisão (telegrafia/peso).
	sprite.modulate = Color(2.0, 0.8, 0.5)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.75), 0.10)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0),  0.20)
	tw.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.22)

	# AoE damage
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) < STOMP_RANGE:
			player.take_damage(STOMP_DAMAGE, global_position)

	VFX.burst(global_position + Vector2(0, 24), get_parent(), Color(0.55, 0.40, 0.18), 28, 160.0, 0.0)
	VFX.ground_burst(global_position + Vector2(0, 28), get_parent(), Color(0.62, 0.45, 0.20), 16)
	VFX.ring(global_position + Vector2(0, 24), get_parent(), Color(0.80, 0.55, 0.20, 0.80), 55.0, 0.40)

	# Phase 2+ fires two shockwaves
	if phase != Phase.ONE:
		_spawn_shockwave(1.0)
		_spawn_shockwave(-1.0)

func _spawn_shockwave(dir: float) -> void:
	var wave = OgreShockwave.instantiate()
	wave.direction = dir
	wave.global_position = global_position + Vector2(dir * 28.0, 8.0)
	get_parent().add_child(wave)

func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return
	var crit := HitZones.is_head_hit(self, from)   # cabeça = crítico (2x)
	if crit:
		amount *= HitZones.CRIT_MULT
	hp -= amount
	if is_instance_valid(hp_bar): hp_bar.show_damage(hp / MAX_HP)
	boss_hp_changed.emit(clampf(hp / MAX_HP, 0.0, 1.0))

	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.global_position = global_position + Vector2(0, -44)
	if crit:
		dmg.setup(amount, HitZones.CRIT_COLOR, true)
	else:
		dmg.setup(amount)

	var kdir = sign(global_position.x - from.x) if from != Vector2.ZERO else 1.0
	if kdir == 0: kdir = 1.0
	knockback = Vector2(kdir * 120.0, -50.0)  # Ogre is very hard to knock back

	AudioManager.play("hit", randf_range(0.84, 1.0))
	var killing := hp <= 0.0
	# squash=false: o ogre anima a própria escala (charge/stomp) — não conflitar.
	VFX.enemy_impact(sprite, global_position, get_parent(), kdir, amount, killing, -36.0, false)
	_flash()
	_check_phase()
	if killing:
		_die()

func _check_phase() -> void:
	var ratio = hp / MAX_HP
	if ratio < 0.60 and not phase2_triggered:
		phase2_triggered = true
		phase = Phase.TWO
		_trigger_phase2()
	if ratio < 0.30 and not phase3_triggered:
		phase3_triggered = true
		phase = Phase.THREE
		_trigger_phase3()

func _trigger_phase2() -> void:
	AudioManager.play("boss_appear")
	if player and is_instance_valid(player):
		player.shake(16.0, 0.7)
	VFX.burst(global_position, get_parent(), Color(0.75, 0.30, 0.08), 40, 200.0, 100.0)
	VFX.ring(global_position, get_parent(), Color(1.00, 0.45, 0.10, 0.90), 80.0, 0.55)
	VFX.ring(global_position, get_parent(), Color(0.90, 0.25, 0.05, 0.65), 120.0, 0.75)
	# Phase 2 text
	_show_phase_text("FASE 2!", Color(1.0, 0.45, 0.08))
	# Spawn two minion goblins after a short delay
	await get_tree().create_timer(0.6).timeout
	if is_dead or not is_instance_valid(self): return
	_spawn_goblin(-90.0)
	_spawn_goblin(90.0)

func _trigger_phase3() -> void:
	AudioManager.play("roar")
	if player and is_instance_valid(player):
		player.shake(22.0, 0.9)
	VFX.burst(global_position, get_parent(), Color(1.0, 0.18, 0.02), 55, 260.0, 80.0)
	VFX.ring(global_position, get_parent(), Color(1.00, 0.10, 0.05, 0.90), 90.0, 0.55)
	VFX.ring(global_position, get_parent(), Color(0.80, 0.08, 0.02, 0.70), 140.0, 0.80)
	VFX.ground_burst(global_position + Vector2(0, 30), get_parent(), Color(1.0, 0.22, 0.05), 24)
	# Phase 3 enrage text
	_show_phase_text("ENRAIVECIDO!", Color(1.0, 0.12, 0.05))
	# Enrage flash — orange tint stays slightly to show phase 3
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.55, 0.35), 0.12)
	tw.tween_property(sprite, "modulate", Color(1.15, 0.85, 0.80), 0.40)

func _spawn_goblin(offset_x: float) -> void:
	var goblin = GoblinScene.instantiate()
	goblin.position = global_position + Vector2(offset_x, 0.0)
	get_parent().add_child(goblin)

func _flash() -> void:
	sprite.modulate = Color(1.6, 0.35, 0.35)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and not is_dead:
		sprite.modulate = Color.WHITE

func _show_phase_text(txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = Vector2(-48, -100)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.14)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.18)
	tw.tween_interval(0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.30)
	tw.tween_callback(lbl.queue_free)

func _die() -> void:
	is_dead = true
	is_charging = false
	is_winding_up = false
	velocity = Vector2.ZERO
	GameState.enemy_died()
	boss_hp_changed.emit(0.0)
	boss_died.emit()
	sprite.modulate = Color(0.55, 0.50, 0.40, 0.55)
	AudioManager.play("enemy_die")
	if player and is_instance_valid(player):
		player.shake(26.0, 1.2)
	# Multi-burst death explosion
	VFX.burst(global_position, get_parent(), Color(0.75, 0.50, 0.20), 70, 240.0, 140.0)
	VFX.ring(global_position, get_parent(), Color(0.90, 0.60, 0.20, 0.90), 100.0, 0.60)
	VFX.ring(global_position, get_parent(), Color(0.70, 0.40, 0.10, 0.65), 160.0, 0.85)
	VFX.ground_burst(global_position + Vector2(0, 32), get_parent(), Color(0.80, 0.55, 0.22), 28)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self):
		VFX.burst(global_position + Vector2(-20, -20), get_parent(), Color(1.0, 0.75, 0.30), 25, 160.0, 80.0)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		queue_free()

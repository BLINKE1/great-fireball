extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -420.0
const GRAVITY = 980.0

const MAGIC_MISSILE_COST  = 15.0
const MAGIC_MISSILE_CD    = 0.18
const TIME_STOP_COST      = 30.0
const TIME_STOP_DURATION  = 3.0
const HEAL_COST           = 40.0
const HEAL_AMOUNT         = 30.0
const DASH_COST           = 20.0
const DASH_SPEED          = 500.0
const DASH_DURATION       = 0.18
const DASH_COOLDOWN       = 0.5
const SWORD_COOLDOWN      = 0.4
const SWORD_FLASH         = 0.1

# New missile variants
const MISSILE_SPREAD_COST     = 22.0
const MISSILE_SPREAD_CD       = 0.32
const MISSILE_PIERCING_COST   = 22.0
const MISSILE_PIERCING_CD     = 0.28
const MISSILE_GIANT_COST      = 50.0
const MISSILE_GIANT_CD        = 1.60

const IFRAME_DURATION   = 1.0
const KNOCKBACK_FORCE   = 300.0
const COYOTE_TIME       = 0.12
const JUMP_BUFFER_TIME  = 0.12

const MagicMissile    = preload("res://scenes/spells/magic_missile.tscn")
const MissileSpread   = preload("res://scenes/spells/missile_spread.tscn")
const MissilePiercing = preload("res://scenes/spells/missile_piercing.tscn")
const MissileGiant    = preload("res://scenes/spells/missile_giant.tscn")
const SwordSlash      = preload("res://scenes/player/sword_slash.tscn")
const DamageNumber    = preload("res://scenes/effects/damage_number.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var hair: Sprite2D   = $Hair
@onready var mana: Node       = $Mana
@onready var hp: Node         = $HP
@onready var camera: Camera2D = $Camera2D

var facing: float = 1.0
var iframe_timer: float = 0.0
var _step_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var sword_timer: float = 0.0
var attack_flash_timer: float = 0.0
var is_dashing: bool = false
var is_dead: bool = false
var is_cutscene: bool = false
var was_on_floor: bool = false
var spawn_position: Vector2
var base_modulate: Color
var jumps_remaining: int = 1
var _ghost_timer: float = 0.0

# Missile cooldown timers
var magic_missile_cd: float = 0.0
var missile_spread_cd: float = 0.0
var missile_piercing_cd: float = 0.0
var missile_giant_cd: float = 0.0

# Screen shake state
var _shake_intensity: float = 0.0
var _shake_duration: float  = 0.0

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position

	var body_tex := SpriteSetup.get_texture("player_body")
	if body_tex:
		sprite.texture = body_tex
		sprite.modulate = Color.WHITE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var hair_tex := SpriteSetup.get_texture("player_hair")
	if hair_tex:
		hair.texture = hair_tex
		hair.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	base_modulate = sprite.modulate
	mana.mana_changed.connect(_on_mana_changed)
	hp.died.connect(_on_died)
	mana.regen_rate = 1.5

func _physics_process(delta: float) -> void:
	_tick_shake(delta)

	if is_dead:
		return

	if is_cutscene or GameState.dialogue_active:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3.0)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	_tick_timers(delta)
	_check_landing()

	if is_dashing:
		velocity.x = facing * DASH_SPEED
		velocity.y = 0.0
		_update_visuals()
		move_and_slide()
		return

	_apply_gravity(delta)
	_handle_jump()
	_handle_movement()
	_handle_spells()
	_update_visuals()
	move_and_slide()

func _tick_timers(delta: float) -> void:
	iframe_timer        = max(iframe_timer        - delta, 0.0)
	jump_buffer_timer   = max(jump_buffer_timer   - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	sword_timer         = max(sword_timer         - delta, 0.0)
	attack_flash_timer  = max(attack_flash_timer  - delta, 0.0)
	_ghost_timer        = max(_ghost_timer        - delta, 0.0)
	_step_timer         = max(_step_timer         - delta, 0.0)
	magic_missile_cd    = max(magic_missile_cd    - delta, 0.0)
	missile_spread_cd   = max(missile_spread_cd   - delta, 0.0)
	missile_piercing_cd = max(missile_piercing_cd - delta, 0.0)
	missile_giant_cd    = max(missile_giant_cd    - delta, 0.0)

	if is_on_floor() and abs(velocity.x) > 20.0 and not is_dashing and _step_timer <= 0.0:
		_step_timer = 0.27
		AudioManager.play("step", randf_range(0.82, 1.18))
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		elif _ghost_timer <= 0.0:
			_ghost_timer = 0.05
			_spawn_dash_ghost()
	if is_on_floor():
		coyote_timer    = COYOTE_TIME
		jumps_remaining = _max_air_jumps()
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

func _tick_shake(delta: float) -> void:
	if _shake_duration > 0.0:
		_shake_duration -= delta
		camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		) * (_shake_duration / max(_shake_duration, 0.001))
	else:
		camera.offset = Vector2.ZERO

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration  = duration

func _check_landing() -> void:
	if is_on_floor() and not was_on_floor:
		AudioManager.play("land")
		VFX.burst(global_position + Vector2(0, 16), get_parent(),
				Color(0.70, 0.58, 0.42, 0.85), 7, 42.0, -15.0)
	was_on_floor = is_on_floor()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _max_air_jumps() -> int:
	return 1 if SkillManager.has("double_jump") else 0

func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
		if not is_on_floor() and coyote_timer <= 0.0 and jumps_remaining > 0:
			velocity.y = JUMP_VELOCITY * 0.85
			jumps_remaining -= 1
			jump_buffer_timer = 0.0
			AudioManager.play("double_jump")
			VFX.burst(global_position, get_parent(), Color(0.5, 0.85, 1.0), 12, 65.0, 30.0)
			return
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jumps_remaining = _max_air_jumps()
		AudioManager.play("jump")

func _handle_movement() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing = direction
		sprite.flip_h = direction < 0
		hair.flip_h   = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func _handle_spells() -> void:
	if Input.is_action_just_pressed("spell_magic_missile"):
		_cast_magic_missile()
	if Input.is_action_just_pressed("spell_missile_spread"):
		_cast_missile_spread()
	if Input.is_action_just_pressed("spell_missile_piercing"):
		_cast_missile_piercing()
	if Input.is_action_just_pressed("spell_missile_giant"):
		_cast_missile_giant()
	if Input.is_action_just_pressed("spell_time_stop"):
		_cast_time_stop()
	if Input.is_action_just_pressed("spell_heal"):
		_cast_heal()
	if Input.is_action_just_pressed("spell_magic_dash"):
		_cast_magic_dash()
	if Input.is_action_just_pressed("attack_sword"):
		_attack_sword()

func _cast_magic_missile() -> void:
	if not SkillManager.has("magic_missile"): return
	if magic_missile_cd > 0.0: return
	if not mana.spend(MAGIC_MISSILE_COST): return
	magic_missile_cd = MAGIC_MISSILE_CD
	AudioManager.play("missile")
	var missile = MagicMissile.instantiate()
	missile.direction = facing
	missile.position = global_position + Vector2(facing * 24, -16)
	get_parent().add_child(missile)

func _cast_missile_spread() -> void:
	if not SkillManager.has("missile_spread"): return
	if missile_spread_cd > 0.0: return
	if not mana.spend(MISSILE_SPREAD_COST): return
	missile_spread_cd = MISSILE_SPREAD_CD
	AudioManager.play("missile_spread")
	VFX.sparkle(global_position + Vector2(facing * 20, -16), get_parent(), Color(0.80, 0.35, 1.0), 8)
	var angles := [-0.18, 0.18]
	for ang in angles:
		var m = MissileSpread.instantiate()
		m.direction    = facing
		m.angle_offset = ang
		m.position     = global_position + Vector2(facing * 20, -16)
		get_parent().add_child(m)

func _cast_missile_piercing() -> void:
	if not SkillManager.has("missile_piercing"): return
	if missile_piercing_cd > 0.0: return
	if not mana.spend(MISSILE_PIERCING_COST): return
	missile_piercing_cd = MISSILE_PIERCING_CD
	AudioManager.play("missile_piercing")
	var m = MissilePiercing.instantiate()
	m.direction = facing
	m.position  = global_position + Vector2(facing * 24, -16)
	get_parent().add_child(m)

func _cast_missile_giant() -> void:
	if not SkillManager.has("missile_giant"): return
	if missile_giant_cd > 0.0: return
	if not mana.spend(MISSILE_GIANT_COST): return
	missile_giant_cd = MISSILE_GIANT_CD
	AudioManager.play("missile_giant")
	shake(3.5, 0.22)
	var m = MissileGiant.instantiate()
	m.direction = facing
	m.position  = global_position + Vector2(facing * 28, -18)
	get_parent().add_child(m)

func _cast_time_stop() -> void:
	if not SkillManager.has("time_stop"): return
	if not mana.spend(TIME_STOP_COST): return
	AudioManager.play("time_stop")
	GameState.start_time_stop(TIME_STOP_DURATION)
	VFX.burst(global_position, get_parent(), Color(0.40, 0.60, 1.00), 28, 130.0, 0.0)
	VFX.ring(global_position, get_parent(), Color(0.50, 0.65, 1.0, 0.90), 60.0, 0.50)

func _cast_heal() -> void:
	if not SkillManager.has("heal"): return
	if not mana.spend(HEAL_COST): return
	AudioManager.play("heal")
	hp.heal(HEAL_AMOUNT)
	VFX.burst(global_position + Vector2(0, -20), get_parent(), Color(0.30, 1.00, 0.50), 22, 95.0, 80.0)
	VFX.ring(global_position, get_parent(), Color(0.28, 1.0, 0.48, 0.80), 30.0, 0.40)
	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.position = global_position + Vector2(0, -32)
	dmg.setup(HEAL_AMOUNT, Color(0.28, 1.0, 0.48))

func _cast_magic_dash() -> void:
	if not SkillManager.has("magic_dash"): return
	if is_dashing or dash_cooldown_timer > 0.0: return
	if not mana.spend(DASH_COST): return
	AudioManager.play("dash")
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	iframe_timer = max(iframe_timer, DASH_DURATION)

func _attack_sword() -> void:
	if sword_timer > 0.0 or is_dashing: return
	sword_timer = SWORD_COOLDOWN
	attack_flash_timer = SWORD_FLASH
	AudioManager.play("sword")
	var slash = SwordSlash.instantiate()
	slash.facing = facing
	slash.global_position = global_position + Vector2(facing * 36, -16)
	get_parent().add_child(slash)

func take_damage(amount: float, source_position: Vector2 = global_position) -> void:
	if iframe_timer > 0.0 or is_dead: return
	hp.take_damage(amount)
	iframe_timer = IFRAME_DURATION
	AudioManager.play("hit_player")
	shake(7.0, 0.28)
	var kdir = sign(global_position.x - source_position.x)
	if kdir == 0: kdir = -facing
	velocity = Vector2(kdir * KNOCKBACK_FORCE, -200.0)

func get_skill_cooldown(skill: String) -> float:
	match skill:
		"magic_dash":        return dash_cooldown_timer / DASH_COOLDOWN
		"sword":             return sword_timer / SWORD_COOLDOWN
		"magic_missile":     return magic_missile_cd / MAGIC_MISSILE_CD if magic_missile_cd > 0.0 \
		                            else (0.0 if mana.current_mana >= MAGIC_MISSILE_COST else 0.75)
		"missile_spread":    return missile_spread_cd / MISSILE_SPREAD_CD if missile_spread_cd > 0.0 \
		                            else (0.0 if mana.current_mana >= MISSILE_SPREAD_COST else 0.75)
		"missile_piercing":  return missile_piercing_cd / MISSILE_PIERCING_CD if missile_piercing_cd > 0.0 \
		                            else (0.0 if mana.current_mana >= MISSILE_PIERCING_COST else 0.75)
		"missile_giant":     return missile_giant_cd / MISSILE_GIANT_CD if missile_giant_cd > 0.0 \
		                            else (0.0 if mana.current_mana >= MISSILE_GIANT_COST else 0.75)
		"time_stop":         return 0.0 if mana.current_mana >= TIME_STOP_COST     else 0.75
		"heal":              return 0.0 if mana.current_mana >= HEAL_COST          else 0.75
		"double_jump":       return 0.0 if jumps_remaining > 0                     else 1.0
	return 0.0

func set_cutscene(active: bool) -> void:
	is_cutscene = active

func _spawn_dash_ghost() -> void:
	if not sprite.texture: return
	var ghost := Sprite2D.new()
	ghost.texture     = sprite.texture
	ghost.flip_h      = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.modulate    = Color(0.35, 0.80, 1.0, 0.55)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.z_index     = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.20)
	tw.tween_callback(ghost.queue_free)

func fall_into_void() -> void:
	if is_dead: return
	is_dead = true
	velocity = Vector2.ZERO
	AudioManager.play("die")
	shake(10.0, 0.45)
	sprite.modulate = Color(0.20, 0.20, 0.45, 1.0)
	_death_fade()

func respawn() -> void:
	is_dead = false
	is_dashing = false
	is_cutscene = false
	jumps_remaining = _max_air_jumps()
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp.restore_full()
	mana.restore_full()
	iframe_timer = IFRAME_DURATION
	sprite.modulate = base_modulate
	hair.modulate   = Color.WHITE

func _update_visuals() -> void:
	if is_on_floor() and abs(velocity.x) < 5.0 and not is_dashing and not is_dead:
		var breathe := 1.0 + 0.018 * sin(Time.get_ticks_msec() * 0.001 * TAU * 0.40)
		sprite.scale = Vector2(breathe, breathe)
		hair.scale   = Vector2(breathe, breathe)
	else:
		sprite.scale = Vector2.ONE
		hair.scale   = Vector2.ONE

	if is_dashing:
		sprite.modulate = Color(0.5, 0.85, 1.0, 1.0)
		return
	if attack_flash_timer > 0.0:
		sprite.modulate = Color(1.6, 1.6, 1.0, 1.0)
		return
	var c = base_modulate
	if iframe_timer > 0.0:
		c.a = 0.4 if fmod(iframe_timer, 0.15) > 0.075 else 1.0
	sprite.modulate = c

func _on_mana_changed(ratio: float) -> void:
	hair.material.set_shader_parameter("mana_ratio", ratio)

func _on_died() -> void:
	is_dead = true
	AudioManager.play("die")
	shake(12.0, 0.5)
	sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	_death_fade()

func _death_fade() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	get_tree().root.add_child(cl)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(overlay)
	var msg := Label.new()
	msg.text = "Você morreu..."
	msg.anchor_left = 0.0; msg.anchor_right = 1.0
	msg.anchor_top = 0.45; msg.anchor_bottom = 0.55
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 32)
	msg.add_theme_color_override("font_color", Color(0.85, 0.18, 0.18))
	msg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	msg.add_theme_constant_override("shadow_offset_x", 2)
	msg.add_theme_constant_override("shadow_offset_y", 2)
	msg.modulate.a = 0.0
	cl.add_child(msg)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.45)
	tw.tween_property(msg, "modulate:a", 1.0, 0.30)
	tw.tween_interval(0.40)
	tw.tween_property(msg, "modulate:a", 0.0, 0.20)
	tw.tween_callback(respawn)
	tw.tween_property(overlay, "color:a", 0.0, 0.55)
	tw.tween_callback(cl.queue_free)

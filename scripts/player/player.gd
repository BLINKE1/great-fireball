extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -420.0
const GRAVITY = 980.0

const MAGIC_MISSILE_COST = 15.0
const TIME_STOP_COST = 30.0
const TIME_STOP_DURATION = 3.0
const HEAL_COST = 40.0
const HEAL_AMOUNT = 30.0
const DASH_COST = 20.0
const DASH_SPEED = 500.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.5
const SWORD_COOLDOWN = 0.4
const SWORD_FLASH = 0.1

const IFRAME_DURATION = 1.0
const KNOCKBACK_FORCE = 300.0
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

const MagicMissile = preload("res://scenes/spells/magic_missile.tscn")
const SwordSlash   = preload("res://scenes/player/sword_slash.tscn")

@onready var sprite: Sprite2D   = $Sprite2D
@onready var hair: Sprite2D     = $Hair
@onready var mana: Node         = $Mana
@onready var hp: Node           = $HP
@onready var camera: Camera2D   = $Camera2D

var facing: float = 1.0
var iframe_timer: float = 0.0
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

# Screen shake state
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position

	# Apply generated pixel art sprites
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
	iframe_timer      = max(iframe_timer      - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	sword_timer       = max(sword_timer       - delta, 0.0)
	attack_flash_timer = max(attack_flash_timer - delta, 0.0)
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	if is_on_floor():
		coyote_timer = COYOTE_TIME
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
	was_on_floor = is_on_floor()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
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
	if not mana.spend(MAGIC_MISSILE_COST): return
	AudioManager.play("missile")
	var missile = MagicMissile.instantiate()
	missile.direction = facing
	missile.position = global_position + Vector2(facing * 24, -16)
	get_parent().add_child(missile)

func _cast_time_stop() -> void:
	if not SkillManager.has("time_stop"): return
	if not mana.spend(TIME_STOP_COST): return
	AudioManager.play("time_stop")
	GameState.start_time_stop(TIME_STOP_DURATION)
	VFX.burst(global_position, get_parent(), Color(0.40, 0.60, 1.00), 28, 130.0, 0.0)

func _cast_heal() -> void:
	if not SkillManager.has("heal"): return
	if not mana.spend(HEAL_COST): return
	AudioManager.play("heal")
	hp.heal(HEAL_AMOUNT)
	VFX.burst(global_position + Vector2(0, -20), get_parent(), Color(0.30, 1.00, 0.50), 22, 95.0, 80.0)

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

func set_cutscene(active: bool) -> void:
	is_cutscene = active

func respawn() -> void:
	is_dead = false
	is_dashing = false
	is_cutscene = false
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp.restore_full()
	mana.restore_full()
	iframe_timer = IFRAME_DURATION
	sprite.modulate = base_modulate
	hair.modulate   = Color.WHITE

func _update_visuals() -> void:
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
	await get_tree().create_timer(1.5).timeout
	respawn()

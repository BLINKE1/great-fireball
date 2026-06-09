extends CharacterBody2D

const SPEED = 40.0
const GRAVITY = 980.0
const DETECT_RANGE = 200.0
const ATTACK_RANGE = 36.0
const ATTACK_DAMAGE = 25.0
const ATTACK_COOLDOWN = 1.8
const MAX_HP = 100.0
const KNOCKBACK_DECAY = 800.0

# Ataque telegrafado (pesado: janela maior, lunge curto).
const ATTACK_WINDUP = 0.42
const ATTACK_LUNGE  = 120.0
const STRIKE_RANGE  = 50.0

const DamageNumber = preload("res://scenes/effects/damage_number.tscn")
const ManaOrb      = preload("res://scenes/world/mana_orb.tscn")

@onready var hp_bar = $HPBar

var hp: float = MAX_HP
var facing: float = 1.0
var patrol_origin: Vector2
var attack_timer: float = 0.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var player: Node = null
var _alerted: bool = false
var _winding: bool = false
var _windup_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	patrol_origin = global_position
	player = get_tree().get_first_node_in_group("player")
	var tex := SpriteSetup.get_texture("golem")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	GameState.time_stop_started.connect(_on_time_stop)
	GameState.time_stop_ended.connect(_on_time_resume)

func _physics_process(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if is_dead or GameState.time_stopped:
		if knockback.length() > 0.0:
			velocity = knockback
			move_and_slide()
		return

	if attack_timer > 0.0:
		attack_timer -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if knockback.length() > 60.0:
		velocity.x = knockback.x
		move_and_slide()
		return

	if _sleep_timer > 0.0:                      # dormindo (Convoke / Juju)
		_sleep_timer -= delta
		$Sprite2D.modulate = Color(0.55, 0.65, 1.05)
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		if _sleep_timer <= 0.0: _wake()
		return

	if _winding:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 10.0 * delta)
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_strike()
	elif player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < DETECT_RANGE:
			if not _alerted:
				_alerted = true
				_show_alert()
			_chase(delta)
			if dist < ATTACK_RANGE and attack_timer <= 0.0:
				_start_windup()
		else:
			_patrol(delta)
	else:
		_patrol(delta)

	move_and_slide()

func _chase(_delta: float) -> void:
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * SPEED
	facing = dir
	$Sprite2D.flip_h = dir < 0

func _patrol(_delta: float) -> void:
	if is_on_floor():
		var space := get_world_2d().direct_space_state
		var check := global_position + Vector2(facing * 22.0, 0.0)
		var params := PhysicsRayQueryParameters2D.create(check, check + Vector2(0.0, 52.0))
		params.exclude = [get_rid()]
		params.collision_mask = 1
		if space.intersect_ray(params).is_empty():
			facing *= -1.0
	velocity.x = facing * SPEED * 0.5
	if abs(global_position.x - patrol_origin.x) > 80.0:
		facing *= -1.0
	$Sprite2D.flip_h = facing < 0

func _on_time_stop() -> void:
	if is_dead: return
	$Sprite2D.create_tween().tween_property($Sprite2D, "modulate", Color(0.55, 0.72, 1.20), 0.14)

func _on_time_resume() -> void:
	if is_dead: return
	$Sprite2D.create_tween().tween_property($Sprite2D, "modulate", Color.WHITE, 0.18)

func _show_alert() -> void:
	AudioManager.play("detect")
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.10))
	lbl.position = Vector2(-5, -58)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.6, 1.6), 0.08)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15)
	tw.tween_interval(0.35)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.24)
	tw.tween_callback(lbl.queue_free)

func _start_windup() -> void:
	_winding = true
	_windup_timer = ATTACK_WINDUP
	facing = sign(player.global_position.x - global_position.x)
	if facing == 0: facing = 1.0
	var s := $Sprite2D
	s.flip_h = facing < 0
	s.modulate = Color(1.8, 1.3, 0.5)   # telegrafia: brilho quente
	s.create_tween().tween_property(s, "position", Vector2(-facing * 5.0, 0.0), ATTACK_WINDUP * 0.8)

func _strike() -> void:
	_winding = false
	attack_timer = ATTACK_COOLDOWN
	var s := $Sprite2D
	s.modulate = Color.WHITE
	s.create_tween().tween_property(s, "position", Vector2.ZERO, 0.08)
	AudioManager.play("enemy_attack", randf_range(0.65, 0.85))
	velocity.x = facing * ATTACK_LUNGE
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) <= STRIKE_RANGE:
			player.take_damage(ATTACK_DAMAGE, global_position)

func _cancel_windup() -> void:
	if not _winding:
		return
	_winding = false
	$Sprite2D.position = Vector2.ZERO

var _sleep_timer: float = 0.0
var _zzz: Label = null

func sleep(dur: float) -> void:
	if is_dead: return
	_sleep_timer = dur
	if has_method("_cancel_windup"): call("_cancel_windup")
	if has_method("_cancel_draw"): call("_cancel_draw")
	$Sprite2D.modulate = Color(0.55, 0.65, 1.05)
	if _zzz == null:
		_zzz = Label.new()
		_zzz.text = "z"
		_zzz.add_theme_font_size_override("font_size", 13)
		_zzz.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		_zzz.position = Vector2(2, -34)
		add_child(_zzz)
		var tw := _zzz.create_tween().set_loops()
		tw.tween_property(_zzz, "position:y", -44.0, 0.8)
		tw.parallel().tween_property(_zzz, "modulate:a", 0.0, 0.8)
		tw.tween_callback(_reset_zzz)

func _reset_zzz() -> void:
	if is_instance_valid(_zzz):
		_zzz.position.y = -34.0; _zzz.modulate.a = 1.0

func _wake() -> void:
	$Sprite2D.modulate = Color.WHITE
	if is_instance_valid(_zzz):
		_zzz.queue_free(); _zzz = null

func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	_cancel_windup()
	hp -= amount
	if is_instance_valid(hp_bar): hp_bar.show_damage(hp / MAX_HP)
	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.global_position = global_position + Vector2(0, -30)
	dmg.setup(amount)
	var kdir = sign(global_position.x - from.x) if from != Vector2.ZERO else 1.0
	if kdir == 0: kdir = 1.0
	knockback = Vector2(kdir * 200.0, -80.0)
	AudioManager.play("hit", randf_range(0.86, 1.04))
	var killing := hp <= 0.0
	VFX.enemy_impact($Sprite2D, global_position, get_parent(), kdir, amount, killing, -24.0)
	_flash()
	if killing:
		_die()

func _flash() -> void:
	$Sprite2D.modulate = Color(1.5, 0.3, 0.3)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and not is_dead:
		$Sprite2D.modulate = Color.WHITE

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	GameState.enemy_died()
	AudioManager.play("enemy_die")
	VFX.burst(global_position + Vector2(0, -18), get_parent(), Color(0.55, 0.50, 0.40), 18, 95.0, 50.0)
	VFX.burst(global_position + Vector2(0, -4), get_parent(), Color(0.38, 0.34, 0.28), 10, 65.0, 18.0)
	if randf() < 0.55:
		var orb = ManaOrb.instantiate()
		orb.position = global_position + Vector2(randf_range(-18, 18), -10)
		get_parent().add_child(orb)
	# Rock shatter: squash down then crumble
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", Vector2(1.35, 0.60), 0.09)
	tw.tween_property($Sprite2D, "scale", Vector2(0.45, 0.45), 0.30)
	tw.parallel().tween_property($Sprite2D, "rotation", randf_range(-0.45, 0.45), 0.30)
	tw.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.34)
	await tw.finished
	if is_instance_valid(self):
		queue_free()

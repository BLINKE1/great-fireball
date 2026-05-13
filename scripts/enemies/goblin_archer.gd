extends CharacterBody2D

const SPEED          = 50.0
const GRAVITY        = 980.0
const DETECT_RANGE   = 380.0
const PREFERRED_DIST = 200.0
const MIN_DIST       = 70.0
const ATTACK_RANGE   = 350.0
const ATTACK_COOLDOWN = 2.2
const MAX_HP         = 30.0
const KNOCKBACK_DECAY = 1100.0

const DamageNumber = preload("res://scenes/effects/damage_number.tscn")
const GoblinArrow  = preload("res://scenes/enemies/goblin_arrow.tscn")
const ManaOrb      = preload("res://scenes/world/mana_orb.tscn")

@onready var hp_bar = $HPBar

var hp: float = MAX_HP
var facing: float = 1.0
var patrol_origin: Vector2
var attack_timer: float = 1.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var player: Node = null
var _alerted: bool = false

func _ready() -> void:
	add_to_group("enemy")
	patrol_origin = global_position
	player = get_tree().get_first_node_in_group("player")
	var tex := SpriteSetup.get_texture("goblin_archer")
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

	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < DETECT_RANGE:
			if not _alerted:
				_alerted = true
				_show_alert()
			_handle_ai(dist)
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0)

	move_and_slide()

func _handle_ai(dist: float) -> void:
	var dir = sign(player.global_position.x - global_position.x)
	facing = dir if dir != 0 else facing
	$Sprite2D.flip_h = facing < 0

	if dist < MIN_DIST:
		# Back away
		velocity.x = -dir * SPEED
	elif dist > PREFERRED_DIST:
		# Approach to preferred distance
		velocity.x = dir * SPEED * 0.5
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 3.0)

	if dist < ATTACK_RANGE and attack_timer <= 0.0:
		_shoot()

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
	lbl.position = Vector2(-5, -52)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.6, 1.6), 0.08)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15)
	tw.tween_interval(0.35)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.24)
	tw.tween_callback(lbl.queue_free)

func _shoot() -> void:
	attack_timer = ATTACK_COOLDOWN
	AudioManager.play("arrow")
	var arrow = GoblinArrow.instantiate()
	arrow.direction = facing
	arrow.position  = global_position + Vector2(facing * 14.0, -12.0)
	get_parent().add_child(arrow)

func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return
	hp -= amount
	if is_instance_valid(hp_bar): hp_bar.show_damage(hp / MAX_HP)
	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.global_position = global_position + Vector2(0, -25)
	dmg.setup(amount)
	var kdir = sign(global_position.x - from.x) if from != Vector2.ZERO else 1.0
	if kdir == 0: kdir = 1.0
	knockback = Vector2(kdir * 280.0, -90.0)
	AudioManager.play("hit")
	GameState.start_hitstop()
	_flash()
	if hp <= 0.0:
		_die()

func _flash() -> void:
	$Sprite2D.modulate = Color(1.5, 0.3, 0.3)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and not is_dead:
		$Sprite2D.modulate = Color.WHITE

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	$Sprite2D.modulate = Color(0.6, 0.6, 0.6, 0.5)
	AudioManager.play("enemy_die")
	if randf() < 0.60:
		var orb = ManaOrb.instantiate()
		orb.position = global_position + Vector2(randf_range(-14, 14), -8)
		get_parent().add_child(orb)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self):
		queue_free()

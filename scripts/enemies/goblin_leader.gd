extends CharacterBody2D

const SPEED = 55.0
const GRAVITY = 980.0
const DETECT_RANGE = 300.0
const ATTACK_RANGE = 36.0
const ATTACK_DAMAGE = 20.0
const ATTACK_COOLDOWN = 1.2
const MAX_HP = 80.0
const KNOCKBACK_DECAY = 1100.0

const DamageNumber = preload("res://scenes/effects/damage_number.tscn")
const ManaOrb      = preload("res://scenes/world/mana_orb.tscn")

@onready var hp_bar = $HPBar

var hp: float = MAX_HP
var facing: float = -1.0
var attack_timer: float = 0.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var player: Node = null
var _alerted: bool = false

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	var tex := SpriteSetup.get_texture("goblin_leader")
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
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * SPEED
			facing = dir
			$Sprite2D.flip_h = dir < 0
			if dist < ATTACK_RANGE and attack_timer <= 0.0:
				attack_timer = ATTACK_COOLDOWN
				AudioManager.play("enemy_attack", randf_range(0.78, 0.95))
				if player.has_method("take_damage"):
					player.take_damage(ATTACK_DAMAGE, global_position)
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

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

func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	hp -= amount
	if is_instance_valid(hp_bar): hp_bar.show_damage(hp / MAX_HP)
	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.global_position = global_position + Vector2(0, -30)
	dmg.setup(amount)
	var kdir = sign(global_position.x - from.x) if from != Vector2.ZERO else 1.0
	if kdir == 0: kdir = 1.0
	knockback = Vector2(kdir * 320.0, -120.0)
	AudioManager.play("hit")
	GameState.start_hitstop(0.08)
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
	AudioManager.play("enemy_die")
	VFX.burst(global_position + Vector2(0, -18), get_parent(), Color(0.78, 0.12, 0.08), 20, 115.0, 58.0)
	VFX.burst(global_position + Vector2(0, -8), get_parent(), Color(0.95, 0.45, 0.08), 10, 72.0, 30.0)
	VFX.ring(global_position + Vector2(0, -12), get_parent(), Color(0.90, 0.30, 0.10, 0.85), 44.0, 0.38)
	if randf() < 0.80:
		var orb = ManaOrb.instantiate()
		orb.position = global_position + Vector2(randf_range(-14, 14), -8)
		get_parent().add_child(orb)
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", Vector2(1.5, 0.55), 0.10)
	tw.tween_property($Sprite2D, "rotation", randf_range(-1.8, 1.8), 0.34)
	tw.parallel().tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.34)
	tw.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.40)
	await tw.finished
	if is_instance_valid(self):
		queue_free()

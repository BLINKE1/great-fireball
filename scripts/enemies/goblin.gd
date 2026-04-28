extends CharacterBody2D

const SPEED = 80.0
const GRAVITY = 980.0
const DETECT_RANGE = 250.0
const ATTACK_RANGE = 32.0
const ATTACK_DAMAGE = 15.0
const ATTACK_COOLDOWN = 1.0
const MAX_HP = 40.0
const KNOCKBACK_DECAY = 1100.0

const DamageNumber = preload("res://scenes/effects/damage_number.tscn")

@onready var hp_bar = $HPBar

var hp: float = MAX_HP
var facing: float = 1.0
var patrol_origin: Vector2
var attack_timer: float = 0.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var player: Node = null

func _ready() -> void:
	add_to_group("enemy")
	patrol_origin = global_position
	player = get_tree().get_first_node_in_group("player")

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
			_chase(delta)
			if dist < ATTACK_RANGE and attack_timer <= 0.0:
				_attack()
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
	velocity.x = facing * SPEED * 0.5
	if abs(global_position.x - patrol_origin.x) > 120.0:
		facing *= -1.0
	$Sprite2D.flip_h = facing < 0

func _attack() -> void:
	attack_timer = ATTACK_COOLDOWN
	if player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE, global_position)

func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	hp -= amount
	if is_instance_valid(hp_bar): hp_bar.show_damage(hp / MAX_HP)
	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.global_position = global_position + Vector2(0, -25)
	dmg.setup(amount)
	var kdir = sign(global_position.x - from.x) if from != Vector2.ZERO else 1.0
	if kdir == 0: kdir = 1.0
	knockback = Vector2(kdir * 300.0, -100.0)
	AudioManager.play("hit")
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
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self):
		queue_free()

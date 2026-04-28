extends Area2D

const SPEED = 300.0
const DAMAGE = 20.0
const LIFETIME = 3.0

var direction: float = 1.0

func _ready() -> void:
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)
		AudioManager.play("hit")
		queue_free()
	elif body.is_in_group("terrain"):
		queue_free()

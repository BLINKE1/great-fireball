extends Area2D

const DAMAGE = 20.0
const LIFETIME = 0.15

var hit_bodies: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_hit(body)

func _on_body_entered(body: Node) -> void:
	_hit(body)

func _hit(body: Node) -> void:
	if body in hit_bodies:
		return
	hit_bodies.append(body)
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)
		AudioManager.play("hit")

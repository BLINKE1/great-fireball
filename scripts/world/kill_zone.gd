extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("fall_into_void"):
		body.fall_into_void()
	elif body.has_method("respawn"):
		body.respawn()
	elif body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(9999.0, body.global_position)

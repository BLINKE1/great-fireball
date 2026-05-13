extends Area2D

const SPEED   = 130.0
const DAMAGE  = 18.0
const LIFETIME = 1.4

var direction: float = 1.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("ogre_shockwave")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.flip_h  = direction < 0
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	# Scale-in animation: starts narrow, expands to full size
	$Sprite2D.scale = Vector2(0.3, 1.0)
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.18).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	if GameState.time_stopped: return
	position.x += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(DAMAGE, global_position)
		VFX.burst(global_position, get_parent(), Color(1.00, 0.55, 0.10), 10, 72.0, 30.0)
		queue_free()
	elif not body.is_in_group("enemy"):
		VFX.burst(global_position, get_parent(), Color(0.90, 0.45, 0.08), 6, 50.0, 20.0)
		queue_free()

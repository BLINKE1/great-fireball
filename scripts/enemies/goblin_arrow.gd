extends Area2D

const SPEED  = 230.0
const DAMAGE = 12.0
const LIFETIME = 3.0

var direction: float = 1.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("goblin_arrow")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = direction < 0
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if GameState.time_stopped: return
	position.x += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(DAMAGE, global_position)
		VFX.burst(global_position, get_parent(), Color(0.82, 0.55, 0.18), 8, 68.0, 28.0)
		queue_free()
	elif not body.is_in_group("enemy"):
		VFX.burst(global_position, get_parent(), Color(0.62, 0.45, 0.15), 5, 48.0, 18.0)
		queue_free()

extends Area2D

const SPEED = 300.0
const DAMAGE = 20.0
const LIFETIME = 3.0

var direction: float = 1.0
var _trail_timer: float = 0.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("magic_missile")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = direction < 0.0
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.045
		VFX.burst(global_position, get_parent(), Color(0.08, 0.65, 1.00), 3, 18.0, 8.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)
		AudioManager.play("hit")
		VFX.burst(global_position, get_parent(), Color(0.22, 0.82, 1.00), 12, 88.0, 22.0)
		queue_free()
	elif body.is_in_group("terrain"):
		VFX.burst(global_position, get_parent(), Color(0.22, 0.82, 1.00), 6, 52.0, 14.0)
		queue_free()

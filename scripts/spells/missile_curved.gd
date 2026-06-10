extends Area2D

const SPEED   = 260.0
const GRAVITY = 380.0
const DAMAGE  = 28.0
const LIFETIME = 3.5

var direction: float = 1.0
var _vel: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("missile_curved")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vel = Vector2(direction * SPEED, -SPEED * 0.52)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_vel.y += GRAVITY * delta
	position += _vel * delta
	$Sprite2D.rotation = _vel.angle()
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.04
		VFX.burst(global_position, get_parent(), Color(0.50, 0.08, 0.92), 2, 16.0, 6.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)  # impacto (som/shake/hitstop) via enemy_impact
		Nails.on_hit(body, global_position)
		VFX.burst(global_position, get_parent(), Color(0.68, 0.18, 1.00), 14, 85.0, 24.0)
		VFX.ring(global_position, get_parent(), Color(0.72, 0.22, 1.0, 0.80), 24.0, 0.28)
		queue_free()
	elif body.is_in_group("terrain"):
		VFX.burst(global_position, get_parent(), Color(0.55, 0.10, 0.85), 6, 50.0, 12.0)
		queue_free()

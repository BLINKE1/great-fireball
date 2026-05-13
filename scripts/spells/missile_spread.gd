extends Area2D

const SPEED   = 285.0
const DAMAGE  = 16.0
const LIFETIME = 2.8

var direction: float = 1.0
var angle_offset: float = 0.0   # radians, positive = downward spread
var _vel: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("missile_spread")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = direction < 0.0

	var ca := cos(abs(angle_offset))
	var sa := sin(angle_offset)
	_vel = Vector2(direction * SPEED * ca, SPEED * sa)
	rotation = angle_offset if direction > 0.0 else PI - angle_offset

	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += _vel * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.055
		VFX.burst(global_position, get_parent(), Color(0.72, 0.25, 1.0), 2, 14.0, 5.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)
		AudioManager.play("hit")
		GameState.start_hitstop(0.04)
		VFX.burst(global_position, get_parent(), Color(0.85, 0.45, 1.0), 10, 70.0, 18.0)
		VFX.ring(global_position, get_parent(), Color(0.80, 0.35, 1.0, 0.80), 22.0, 0.28)
		queue_free()
	elif body.is_in_group("terrain"):
		VFX.burst(global_position, get_parent(), Color(0.75, 0.35, 1.0), 4, 36.0, 10.0)
		queue_free()

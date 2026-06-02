extends Area2D

const SPEED   = 240.0
const DAMAGE  = 28.0
const LIFETIME = 3.5

var direction: float = 1.0
var _trail_timer: float = 0.0
var _hit_bodies: Array = []

func _ready() -> void:
	var tex := SpriteSetup.get_texture("missile_piercing")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = direction < 0.0
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.04
		VFX.burst(global_position, get_parent(), Color(0.08, 0.95, 0.60), 2, 16.0, 4.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body in _hit_bodies:
			return
		_hit_bodies.append(body)
		body.take_damage(DAMAGE, global_position)  # impacto (som/shake/hitstop) via enemy_impact
		VFX.burst(global_position, get_parent(), Color(0.12, 1.00, 0.65), 12, 80.0, 22.0)
		VFX.ring(global_position, get_parent(), Color(0.10, 0.95, 0.60, 0.85), 20.0, 0.25)
		# Piercing — does NOT queue_free on enemy hit
	elif body.is_in_group("terrain"):
		VFX.burst(global_position, get_parent(), Color(0.10, 0.90, 0.60), 6, 48.0, 14.0)
		queue_free()

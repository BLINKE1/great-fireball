extends Area2D

const SPEED    = 215.0
const GRAVITY  = 200.0
const DAMAGE   = 10.0
const BURN_DPS = 5.0
const BURN_DUR = 3.0
const LIFETIME = 2.8

var direction: float = 1.0
var _vy: float = 0.0
var _trail_timer: float = 0.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("fire_goblin_arrow")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = direction < 0
	add_to_group("enemy_projectile")
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if GameState.time_stopped: return
	_vy += GRAVITY * delta
	position.x += direction * SPEED * delta
	position.y += _vy * delta
	$Sprite2D.rotation = atan2(_vy, SPEED) * direction
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.055
		VFX.burst(global_position, get_parent(), Color(1.0, 0.52, 0.08), 2, 14.0, 6.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(DAMAGE, global_position)
		if body.has_method("apply_burn"):
			body.apply_burn(BURN_DPS, BURN_DUR)
		VFX.burst(global_position, get_parent(), Color(1.0, 0.60, 0.12), 10, 72.0, 30.0)
		VFX.ring(global_position, get_parent(), Color(1.0, 0.50, 0.10, 0.75), 18.0, 0.22)
		queue_free()
	elif not body.is_in_group("enemy"):
		VFX.burst(global_position, get_parent(), Color(0.90, 0.45, 0.10), 6, 50.0, 18.0)
		queue_free()

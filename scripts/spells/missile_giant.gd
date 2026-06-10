extends Area2D

const SPEED   = 155.0
const DAMAGE  = 72.0
const LIFETIME = 4.0

var direction: float = 1.0
var _trail_timer: float = 0.0
var _player_ref: Node = null

func _ready() -> void:
	var tex := SpriteSetup.get_texture("missile_giant")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = direction < 0.0
	$Sprite2D.scale  = Vector2(1.4, 1.4)

	_player_ref = get_tree().get_first_node_in_group("player")

	# Entry VFX — charging effect
	VFX.ring(global_position, get_parent(), Color(0.55, 0.92, 1.0, 0.90), 35.0, 0.40)
	VFX.burst(global_position, get_parent(), Color(0.35, 0.80, 1.0), 18, 100.0, 5.0)

	get_tree().create_timer(LIFETIME).timeout.connect(_on_expire)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.06
		VFX.burst(global_position, get_parent(), Color(0.30, 0.78, 1.0), 5, 22.0, 6.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)
		Nails.on_hit(body, global_position)
		_explode()
	elif body.is_in_group("terrain"):
		_explode()

func _on_expire() -> void:
	_explode()

func _explode() -> void:
	AudioManager.play("missile_giant_hit")
	VFX.burst(global_position, get_parent(), Color(0.45, 0.90, 1.0), 35, 160.0, 20.0)
	VFX.burst(global_position, get_parent(), Color(1.00, 1.00, 1.00), 15, 80.0,  8.0)
	VFX.ring(global_position, get_parent(), Color(0.55, 0.95, 1.0, 1.0), 70.0, 0.45)
	VFX.ring(global_position, get_parent(), Color(0.30, 0.75, 1.0, 0.70), 100.0, 0.60)
	GameState.start_hitstop(0.09)
	if is_instance_valid(_player_ref) and _player_ref.has_method("shake"):
		_player_ref.shake(8.0, 0.40)
	queue_free()

extends Area2D

const SPEED = 300.0
const DAMAGE = 40.0   # crítico (cabeça) = 80 → one-shot até no goblin_leader (80 HP)
const LIFETIME = 3.0

var direction: float = 1.0
var aim_dir: Vector2 = Vector2.ZERO   # se setado (mira livre), anda em qualquer angulo
var _trail_timer: float = 0.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("magic_missile")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# compat: sem mira livre, deriva do facing (eixo X)
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(direction, 0.0)
	aim_dir = aim_dir.normalized()
	rotation = aim_dir.angle()        # aponta na direcao do disparo
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += aim_dir * SPEED * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.045
		VFX.burst(global_position, get_parent(), Color(0.08, 0.65, 1.00), 3, 18.0, 8.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)  # impacto (som/shake/hitstop) via enemy_impact
		Nails.on_hit(body, global_position)        # afinidade elemental das unhas
		VFX.burst(global_position, get_parent(), Color(0.22, 0.82, 1.00), 12, 88.0, 22.0)
		VFX.ring(global_position, get_parent(), Color(0.25, 0.85, 1.0, 0.75), 20.0, 0.25)
		queue_free()
	elif body.is_in_group("terrain"):
		VFX.burst(global_position, get_parent(), Color(0.22, 0.82, 1.00), 6, 52.0, 14.0)
		queue_free()

extends Area2D

const DAMAGE = 20.0
const LIFETIME = 0.15

var hit_bodies: Array = []
var parried: Array = []
var facing: float = 1.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("sword_slash_arc")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = facing < 0
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	VFX.burst(global_position, get_parent(), Color(0.95, 0.88, 0.55), 9, 105.0, -28.0)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_hit(body)
	for area in get_overlapping_areas():
		_try_parry(area)

func _on_body_entered(body: Node) -> void:
	_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_parry(area)

# Parry: cortar uma flecha (ou outro projétil aparável) que entra no golpe.
# A janela curta do slash (LIFETIME) já É o "tempo certo" — aparar é skill.
func _try_parry(area: Node) -> void:
	if area in parried:
		return
	if not area.is_in_group("enemy_projectile") or not area.has_method("parry"):
		return
	parried.append(area)
	area.parry(global_position)
	# Juice do parry: clang agudo, freeze curtinho, micro-shake.
	AudioManager.play("sword", randf_range(1.35, 1.5))
	GameState.start_hitstop(0.08)
	var p := get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and p.has_method("shake"):
		p.shake(5.0, 0.14)

func _hit(body: Node) -> void:
	if body in hit_bodies:
		return
	hit_bodies.append(body)
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)  # impacto (som/shake/hitstop) via enemy_impact
		Nails.on_hit(body, global_position)        # afinidade elemental das unhas (cajado)
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("gain_mana_from_melee"):
			p.gain_mana_from_melee()   # agressão recarrega mana (modelo híbrido)

extends Area2D

const DAMAGE = 20.0
const LIFETIME = 0.15

var hit_bodies: Array = []
var facing: float = 1.0

func _ready() -> void:
	var tex := SpriteSetup.get_texture("sword_slash_arc")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.flip_h = facing < 0
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	VFX.burst(global_position, get_parent(), Color(0.95, 0.88, 0.55), 9, 105.0, -28.0)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_hit(body)

func _on_body_entered(body: Node) -> void:
	_hit(body)

func _hit(body: Node) -> void:
	if body in hit_bodies:
		return
	hit_bodies.append(body)
	if body.is_in_group("enemy"):
		body.take_damage(DAMAGE, global_position)  # impacto (som/shake/hitstop) via enemy_impact
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("gain_mana_from_melee"):
			p.gain_mana_from_melee()   # agressão recarrega mana (modelo híbrido)

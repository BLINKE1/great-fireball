extends Area2D

const RESTORE_AMOUNT = 15.0
const ATTRACT_RANGE  = 90.0
const ATTRACT_SPEED  = 180.0

var _player: Node = null

func _ready() -> void:
	var tex := SpriteSetup.get_texture("mana_orb")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")
	# Gentle float + scale pulse animation
	var tw := create_tween().set_loops()
	tw.tween_property($Sprite2D, "position:y", -6.0, 0.85).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property($Sprite2D, "position:y",  0.0, 0.85).set_ease(Tween.EASE_IN_OUT)
	var tw2 := create_tween().set_loops()
	tw2.tween_property($Sprite2D, "scale", Vector2(1.22, 1.22), 0.70).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property($Sprite2D, "scale", Vector2(1.00, 1.00), 0.70).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player): return
	var ppos: Vector2 = (_player as Node2D).global_position
	var dist := global_position.distance_to(ppos)
	if dist < ATTRACT_RANGE and dist > 1.0:
		var pull := 1.0 - (dist / ATTRACT_RANGE)   # 0 at edge, 1 at center
		var speed := ATTRACT_SPEED * (0.4 + pull * 1.6)
		var dir := (ppos - global_position).normalized()
		global_position += dir * speed * delta

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"): return
	body.mana.restore(RESTORE_AMOUNT)
	AudioManager.play("orb_pickup")
	VFX.burst(global_position, get_parent(), Color(0.22, 0.56, 1.0), 10, 58.0, 45.0)
	queue_free()

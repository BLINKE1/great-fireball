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
var _parried: bool = false

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
	if _parried: return
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

# ── Parry: a espada corta a flecha de fogo no ar ──────────────────────────────
# Mesma mecânica da goblin_arrow: o sword_slash chama isto no timing certo, a
# flecha parte ao meio (faíscas de brasa) e some — o player escapa do hit (e do
# burn). Genérico via has_method("parry").
func parry(_from: Vector2 = Vector2.ZERO) -> void:
	if _parried: return
	_parried = true
	set_deferred("monitoring", false)
	_split()
	queue_free()

func _split() -> void:
	var parent := get_parent()
	if parent == null: return
	var tex: Texture2D = $Sprite2D.texture
	var rot: float = $Sprite2D.global_rotation
	for i in 2:
		var half := Sprite2D.new()
		half.texture = tex
		half.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		half.global_position = global_position
		half.rotation = rot
		half.flip_h = $Sprite2D.flip_h
		half.modulate = Color(1.0, 0.70, 0.30)
		if tex:
			var sz := tex.get_size()
			half.region_enabled = true
			half.region_rect = Rect2(0, 0, sz.x * 0.5, sz.y) if i == 0 \
				else Rect2(sz.x * 0.5, 0, sz.x * 0.5, sz.y)
		parent.add_child(half)
		var up := -1.0 if i == 0 else 1.0
		var tw := half.create_tween()
		tw.set_parallel(true)
		tw.tween_property(half, "position",
			half.position + Vector2(-direction * 18.0, up * 38.0), 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(half, "rotation", rot + up * 6.0, 0.45)
		tw.tween_property(half, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(half.queue_free)
	# Brasas espirrando + anel quente no corte.
	VFX.burst(global_position, get_parent(), Color(1.0, 0.65, 0.20), 14, 96.0, 26.0)
	VFX.ring(global_position, get_parent(), Color(1.0, 0.75, 0.35, 0.80), 14.0, 0.20)

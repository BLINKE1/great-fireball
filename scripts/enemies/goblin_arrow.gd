extends Area2D

const SPEED   = 270.0     # 230 → mais veloz: lê como ameaça real (compensada pelo parry)
const GRAVITY = 220.0
const DAMAGE  = 16.0      # 12 → ranged mais punitivo; recompensa aparar no tempo certo
const LIFETIME = 2.8

var direction: float = 1.0
var _vy: float = 0.0
var _trail_timer: float = 0.0
var _parried: bool = false

func _ready() -> void:
	var tex := SpriteSetup.get_texture("goblin_arrow")
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
	# Tilt arrow downward as it drops
	$Sprite2D.rotation = atan2(_vy, SPEED) * direction
	# Rastro quente: vende velocidade/peso da flecha (igual ao trail do missile).
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.04
		VFX.burst(global_position, get_parent(), Color(0.85, 0.55, 0.18), 2, 14.0, 6.0)

func _on_body_entered(body: Node) -> void:
	if _parried: return
	if body.is_in_group("player"):
		body.take_damage(DAMAGE, global_position)
		# Impacto reforçado: faísca direcional + estilhaço + anel de choque.
		VFX.hit_spark(global_position, get_parent(), direction)
		VFX.burst(global_position, get_parent(), Color(0.95, 0.62, 0.22), 14, 96.0, 32.0)
		VFX.ring(global_position, get_parent(), Color(1.0, 0.70, 0.30, 0.70), 18.0, 0.22)
		queue_free()
	elif not body.is_in_group("enemy"):
		VFX.burst(global_position, get_parent(), Color(0.62, 0.45, 0.15), 6, 52.0, 18.0)
		queue_free()

# ── Parry: a espada corta a flecha no ar ──────────────────────────────────────
# Chamado pelo sword_slash quando o golpe pega a flecha em voo. Parte ela ao meio
# (dois pedaços girando) e some — o player escapa do hit por mérito do timing.
func parry(_from: Vector2 = Vector2.ZERO) -> void:
	if _parried: return
	_parried = true
	set_deferred("monitoring", false)   # não dana mais nada neste frame
	_split()
	queue_free()

func _split() -> void:
	var parent := get_parent()
	if parent == null: return
	var tex: Texture2D = $Sprite2D.texture
	var rot: float = $Sprite2D.global_rotation
	# Dois meio-pedaços: um sobe/recua, o outro desce — giram e desvanecem.
	for i in 2:
		var half := Sprite2D.new()
		half.texture = tex
		half.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		half.global_position = global_position
		half.rotation = rot
		half.flip_h = $Sprite2D.flip_h
		half.modulate = Color(0.95, 0.80, 0.50)
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
	# Lampejo do corte + faísca branca (o "clang" visual).
	VFX.burst(global_position, get_parent(), Color(1.0, 0.95, 0.70), 12, 92.0, 24.0)
	VFX.ring(global_position, get_parent(), Color(1.0, 1.0, 0.85, 0.80), 14.0, 0.20)

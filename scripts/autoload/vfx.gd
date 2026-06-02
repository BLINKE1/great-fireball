extends Node

# Spawns one-shot CPUParticles2D burst effects anywhere in the world.
# Usage: VFX.burst(global_position, get_parent(), Color(0.3, 1.0, 0.5))

func burst(
		world_pos: Vector2,
		parent: Node,
		color: Color,
		count: int = 14,
		speed: float = 80.0,
		gravity_y: float = 220.0) -> void:
	if not is_instance_valid(parent): return

	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.global_position = world_pos

	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.55
	p.local_coords = false

	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, gravity_y)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.color_ramp = _fade_gradient(color)

	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(p):
		p.queue_free()

# Directional impact spark — punchy hit feedback for melee/projectile contact.
func hit_spark(world_pos: Vector2, parent: Node, dir: float = 1.0,
		color: Color = Color(1.0, 0.95, 0.62)) -> void:
	if not is_instance_valid(parent): return
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 9
	p.lifetime = 0.26
	p.local_coords = false
	p.direction = Vector2(dir, -0.2)   # esguicha no sentido do golpe
	p.spread = 42.0
	p.gravity = Vector2(0, 140.0)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.5
	p.color = color
	p.color_ramp = _fade_gradient(color)
	ring(world_pos, parent, Color(1, 1, 1, 0.85), 20.0, 0.16)  # estalo branco
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(p):
		p.queue_free()
func ring(world_pos: Vector2, parent: Node, color: Color, radius: float = 40.0, duration: float = 0.35) -> void:
	if not is_instance_valid(parent): return
	var ring_node := _RingNode.new()
	ring_node.ring_color = color
	ring_node.start_radius = radius * 0.1
	ring_node.end_radius   = radius
	ring_node.duration     = duration
	parent.add_child(ring_node)
	ring_node.global_position = world_pos
	await get_tree().create_timer(duration + 0.05).timeout
	if is_instance_valid(ring_node):
		ring_node.queue_free()

# Sparkle burst — smaller particles that linger longer (good for magic).
func sparkle(world_pos: Vector2, parent: Node, color: Color, count: int = 18) -> void:
	if not is_instance_valid(parent): return
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = count
	p.lifetime = 0.85
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 60.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.color_ramp = _fade_gradient(color)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(p):
		p.queue_free()

# Shockwave flash on ground — horizontal burst staying near Y.
func ground_burst(world_pos: Vector2, parent: Node, color: Color, count: int = 20) -> void:
	if not is_instance_valid(parent): return
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = 0.45
	p.local_coords = false
	p.direction = Vector2(1, 0)
	p.spread = 35.0
	p.gravity = Vector2(0, 320.0)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = color
	p.color_ramp = _fade_gradient(color)
	# Mirror burst
	var p2 := p.duplicate() as CPUParticles2D
	parent.add_child(p2)
	p2.global_position = world_pos
	p2.direction = Vector2(-1, 0)
	p2.emitting = true
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(p):  p.queue_free()
	if is_instance_valid(p2): p2.queue_free()

# ── Juice de impacto reutilizável (todo inimigo bate igual de gostoso) ────────
# Chame de take_damage DEPOIS de calcular kdir/killing. Centraliza o "tato":
# hitstop escalado, faísca direcional, screenshake proporcional e squash ao
# apanhar. Cada inimigo segue dono do seu flash/knockback/morte/HP.
func enemy_impact(sprite: Node2D, world_pos: Vector2, parent: Node, kdir: float,
		amount: float, killing: bool, top_offset: float = -16.0) -> void:
	# Hitstop escalado: o golpe letal congela mais (o "crunch").
	var freeze := 0.11 if killing else clampf(0.045 + amount * 0.0022, 0.045, 0.10)
	GameState.start_hitstop(freeze)
	# Faísca direcional + estalo branco, esguichando no sentido do golpe.
	hit_spark(world_pos + Vector2(-kdir * 10.0, top_offset), parent, -kdir)
	# Screenshake proporcional ao dano (via câmera do player).
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("shake"):
		pl.shake(clampf(amount * 0.16, 2.5, 7.0), 0.13)
	# Squash elástico ao apanhar (só em hit não-letal; a morte tem sua animação).
	# rest_scale em meta → robusto a hits repetidos e a sprites com escala != 1.
	if not killing and is_instance_valid(sprite):
		if not sprite.has_meta("rest_scale"):
			sprite.set_meta("rest_scale", sprite.scale)
		var base: Vector2 = sprite.get_meta("rest_scale")
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale", base * Vector2(1.26, 0.76), 0.05)
		tw.tween_property(sprite, "scale", base, 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_gradient(base: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, base)
	g.set_color(1, Color(base.r, base.g, base.b, 0.0))
	return g

# ── Internal ring drawing node ────────────────────────────────────────────────

class _RingNode extends Node2D:
	var ring_color: Color = Color.WHITE
	var start_radius: float = 5.0
	var end_radius: float   = 40.0
	var duration: float     = 0.35
	var _t: float           = 0.0

	func _process(delta: float) -> void:
		_t += delta / duration
		queue_redraw()
		if _t >= 1.0:
			set_process(false)

	func _draw() -> void:
		var r   := lerpf(start_radius, end_radius, _t)
		var alp := (1.0 - _t) * ring_color.a
		var c   := Color(ring_color.r, ring_color.g, ring_color.b, alp)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, c, 2.5, true)

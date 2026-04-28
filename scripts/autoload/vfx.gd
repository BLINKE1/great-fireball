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

func _fade_gradient(base: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, base)
	g.set_color(1, Color(base.r, base.g, base.b, 0.0))
	return g

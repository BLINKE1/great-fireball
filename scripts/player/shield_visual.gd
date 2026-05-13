extends Node2D

var active: bool = false
var _alpha: float = 0.0
var _pulse: float = 0.0
var _hit_flash: float = 0.0

func activate() -> void:
	active = true

func deactivate() -> void:
	active = false

func hit_flash() -> void:
	_hit_flash = 0.30

func _process(delta: float) -> void:
	if active:
		_alpha = minf(_alpha + delta * 6.0, 1.0)
	else:
		_alpha = maxf(_alpha - delta * 3.5, 0.0)
	_pulse += delta * 3.8
	_hit_flash = maxf(_hit_flash - delta * 5.0, 0.0)
	if _alpha > 0.001:
		queue_redraw()

func _draw() -> void:
	if _alpha <= 0.001: return
	var f := _hit_flash
	var r := 28.0 + sin(_pulse) * 3.5
	# Outer glow ring
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 52,
			Color(0.30 + f * 0.6, 0.68 + f * 0.2, 1.0, _alpha * 0.60), 3.5)
	# Inner ring
	draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 40,
			Color(0.55 + f * 0.4, 0.88, 1.0, _alpha * 0.38), 2.0)
	# Orbiting dots
	for i in 6:
		var angle := _pulse * 0.45 + i * TAU / 6.0
		var dp := Vector2(cos(angle), sin(angle)) * (r - 1.5)
		draw_circle(dp, 2.2, Color(0.80 + f, 0.95, 1.0, _alpha * 0.82))

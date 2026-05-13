extends Node2D

@export var bar_width: float = 32.0

var ratio: float = 1.0
var _timer: float = 0.0

func _ready() -> void:
	visible = false

func show_damage(hp_ratio: float) -> void:
	ratio = clamp(hp_ratio, 0.0, 1.0)
	_timer = 2.5
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			visible = false

func _draw() -> void:
	var h := 6.0
	var w := bar_width
	# Border
	draw_rect(Rect2(-w * 0.5 - 1, -h * 0.5 - 1, w + 2, h + 2), Color(0.0, 0.0, 0.0, 0.80))
	# Background track
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.10, 0.10, 0.14, 0.90))
	if ratio > 0.0:
		var col := Color(0.85, 0.15, 0.10, 1.0)
		if ratio > 0.6:
			col = Color(0.18, 0.80, 0.20, 1.0)
		elif ratio > 0.3:
			col = Color(0.92, 0.52, 0.08, 1.0)
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w * ratio, h), col)
		# Shine strip on top of bar
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w * ratio, 2.0),
				Color(1.0, 1.0, 1.0, 0.22))

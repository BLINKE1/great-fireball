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
	var h := 5.0
	var w := bar_width
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.12, 0.12, 0.12, 0.88))
	if ratio > 0.0:
		var col := Color(0.85, 0.15, 0.15, 0.92)
		if ratio > 0.6:
			col = Color(0.2, 0.78, 0.2, 0.92)
		elif ratio > 0.3:
			col = Color(0.9, 0.55, 0.1, 0.92)
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w * ratio, h), col)

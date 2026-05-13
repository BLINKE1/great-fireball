extends Node2D

func setup(amount: float, color: Color = Color(1.0, 0.90, 0.08)) -> void:
	$Label.text = str(int(amount))
	$Label.modulate = color
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 52.0, 0.72).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($Label, "modulate:a", 0.0, 0.72)
	tween.tween_callback(queue_free)

extends Node2D

func setup(amount: float) -> void:
	$Label.text = str(int(amount))
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 50.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($Label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(queue_free)

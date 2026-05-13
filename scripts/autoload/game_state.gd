extends Node

var time_stopped: bool = false
var dialogue_active: bool = false
var kill_count: int = 0
var _session_start: float = 0.0

signal time_stop_started
signal time_stop_ended

func start_time_stop(duration: float) -> void:
	if time_stopped:
		return
	time_stopped = true
	time_stop_started.emit()
	await get_tree().create_timer(duration).timeout
	time_stopped = false
	time_stop_ended.emit()

# Brief freeze-frame on hit — creates satisfying impact feedback.
# duration is real-world seconds (ignores time_scale).
func start_hitstop(duration: float = 0.06) -> void:
	if Engine.time_scale < 1.0 or time_stopped:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, false, false, true).timeout
	Engine.time_scale = 1.0

func start_session() -> void:
	kill_count = 0
	_session_start = Time.get_ticks_msec() / 1000.0

func enemy_died() -> void:
	kill_count += 1

func get_elapsed_time() -> String:
	var secs := int(Time.get_ticks_msec() / 1000.0 - _session_start)
	return "%d:%02d" % [secs / 60, secs % 60]

func reset_state() -> void:
	time_stopped = false
	dialogue_active = false
	Engine.time_scale = 1.0
	kill_count = 0

func fade_out_then(callback: Callable, duration: float = 0.42) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 48
	get_tree().root.add_child(cl)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(overlay)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 1.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(callback)
	tw.tween_callback(cl.queue_free)

func fade_in(duration: float = 0.55) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 48
	get_tree().root.add_child(cl)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(overlay)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tw.tween_callback(cl.queue_free)

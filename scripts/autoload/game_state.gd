extends Node

var time_stopped: bool = false
var dialogue_active: bool = false

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

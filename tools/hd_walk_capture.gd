extends SceneTree
var _f := 0; var _lvl; var _shot := 0
func _tap_accept():
	var ev := InputEventAction.new()
	ev.action = "ui_accept"; ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = "ui_accept"; ev2.pressed = false
	Input.parse_input_event.call_deferred(ev2)
func _initialize():
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)
func _process(_d):
	_f += 1
	if _f >= 30 and _f <= 120 and _f % 15 == 0: _tap_accept()
	if _f == 190: Input.action_press("ui_right")
	if _f >= 196 and _f <= 220 and _f % 4 == 0:
		var img := get_root().get_texture().get_image()
		if img: img.save_png("/tmp/walk_shot_%d.png" % _shot); _shot += 1
	if _f < 221: return false
	print("done ", _shot)
	quit(0); return true

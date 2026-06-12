extends SceneTree
var _f := 0; var _lvl; var _shot := 0
func _tap(action):
	var ev := InputEventAction.new()
	ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = action; ev2.pressed = false
	Input.parse_input_event.call_deferred(ev2)
func _initialize():
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)
func _process(_d):
	_f += 1
	if _f >= 30 and _f <= 120 and _f % 15 == 0: _tap("ui_accept")
	if _f == 200: _tap("spell_magic_missile")
	if _f == 230: _tap("attack_sword")
	if _f in [203, 208, 233, 238]:
		var img := get_root().get_texture().get_image()
		if img: img.save_png("/tmp/cast_shot_%d.png" % _shot); _shot += 1
	if _f < 240: return false
	print("done ", _shot)
	quit(0); return true

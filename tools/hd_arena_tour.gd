extends SceneTree
## Tour da Soph HD na arena de testes v2: idle, run, jump/fall, cast, slash.
var _f := 0; var _room; var _shot := 0
func _tap(action):
	var ev := InputEventAction.new()
	ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = action; ev2.pressed = false
	Input.parse_input_event.call_deferred(ev2)
func _snap(tag):
	var img := get_root().get_texture().get_image()
	if img: img.save_png("/tmp/arena_%02d_%s.png" % [_shot, tag]); _shot += 1
func _initialize():
	_room = load("res://scenes/world/soph_test_room2.tscn").instantiate()
	get_root().add_child.call_deferred(_room)
func _process(_d):
	_f += 1
	if _f == 50: _snap("idle")
	if _f == 60: Input.action_press("ui_right")
	if _f == 85: _snap("run")
	if _f == 95: _snap("run2")
	if _f == 100: Input.action_release("ui_right")
	if _f == 130: _tap("ui_accept")
	if _f == 137: _snap("jump")
	if _f == 158: _snap("fall")
	if _f == 200: _tap("spell_magic_missile")
	if _f == 204: _snap("cast")
	if _f == 209: _snap("cast2")
	if _f == 250: _tap("attack_sword")
	if _f == 254: _snap("slash")
	if _f == 259: _snap("slash2")
	if _f < 270: return false
	print("done ", _shot)
	quit(0); return true

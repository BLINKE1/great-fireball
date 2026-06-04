extends SceneTree
## Demo do movimento da Soph (idle -> corrida c/ lean -> pulo). Captura -> GIF.
var _room; var _p; var _f := 0; var _landed := false; var _lf := 0; var _shots := 0
func _initialize():
	_room = load("res://scenes/world/soph_test_room.tscn").instantiate()
	get_root().add_child.call_deferred(_room)
func _process(_d) -> bool:
	_f += 1
	if _p == null and _room: _p = _room.get_node_or_null("Player")
	if _p == null: return false
	if not _landed:
		if _p.is_on_floor(): _landed = true; _lf = _f
		return false
	var t := _f - _lf
	if t == 14: Input.action_press("ui_right")
	if t == 34: Input.action_press("ui_accept")
	if t == 36: Input.action_release("ui_accept")
	if t == 70: Input.action_release("ui_right")
	# captura a janela do movimento
	if t >= 10 and t <= 78 and _shots < 64:
		var img := get_root().get_texture().get_image()
		if img: img.save_png("/tmp/move/frame_%03d.png" % _shots); _shots += 1
	if t >= 80:
		print("MOVE shots: ", _shots); quit(0); return true
	return false

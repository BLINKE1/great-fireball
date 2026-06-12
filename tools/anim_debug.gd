extends SceneTree
var _f := 0; var _lvl; var _p
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
	if _p == null and _lvl: _p = _lvl.get_node_or_null("Player")
	if _f >= 30 and _f <= 120 and _f % 15 == 0: _tap_accept()
	if _f == 190: Input.action_press("ui_right")
	if _f in [200, 210, 220] and _p:
		var spr = _p.get_node("Sprite2D")
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
		print("f=", _f, " anim=", spr.animation, ":", spr.frame,
			" floor=", _p.is_on_floor(), " pos=", _p.global_position.round(),
			" tex=", tex.get_size(), " path=", tex.resource_path)
	if _f == 221 and _p:
		var spr = _p.get_node("Sprite2D")
		var t0: Texture2D = spr.sprite_frames.get_frame_texture("walk", 0)
		t0.get_image().save_png("/tmp/frames_walk0.png")
		print("frames_walk0 salvo, path=", t0.resource_path)
	if _f < 222: return false
	quit(0); return true

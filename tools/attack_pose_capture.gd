extends SceneTree
## Valida as poses de ataque chamando os métodos direto (sem timing de input).
var _room; var _p; var _f := 0; var _landed := false; var _lf := 0
var _saw_cast := false; var _saw_slash := false
var _out := "res://tools/art_director/iterations/godot_shots/"
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
	var spr = _p.get_node("Sprite2D")
	if t == 6:
		_p._cast_magic_missile(); _p._update_anim()
		_saw_cast = (spr.animation == "cast")
		print("cast -> anim: ", spr.animation, " | pose_timer: ", _p._attack_pose_timer)
	elif t == 8:
		_shot("pose_cast")
	elif t == 20:
		_p._attack_sword(); _p._update_anim()
		_saw_slash = (spr.animation == "slash")
		print("slash -> anim: ", spr.animation, " | sword_timer: ", _p.sword_timer, " pose_timer: ", _p._attack_pose_timer)
	elif t == 22:
		_shot("pose_slash")
	elif t >= 30:
		print("RESULTADO poses: cast=%s slash=%s" % [_saw_cast, _saw_slash])
		quit(0 if (_saw_cast and _saw_slash) else 1); return true
	return false
func _shot(tag):
	var img := get_root().get_texture().get_image()
	if img: img.save_png(ProjectSettings.globalize_path(_out + tag + ".png"))

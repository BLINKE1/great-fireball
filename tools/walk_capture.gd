extends SceneTree
## Captura a Soph HD andando/correndo renderizada no engine (escala/flip reais).
## Desliga a logica do player e dirige o AnimatedSprite2D direto.
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/walk_capture.gd

var _room; var _p; var _spr; var _cam: Camera2D
var _f := 0; var _phase := 0; var _shots := 0; var _i := 0
var _armed := ""
var _seq := [["walk", 0], ["walk", 1], ["walk", 2], ["walk", 3],
			 ["run", 0], ["run", 1]]
var _out := "res://tools/art_director/iterations/godot_shots/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_room = load("res://scenes/world/soph_test_room.tscn").instantiate()
	get_root().add_child.call_deferred(_room)
	_cam = Camera2D.new()
	get_root().add_child.call_deferred(_cam)

func _process(_d: float) -> bool:
	_f += 1
	if _p == null:
		if _room:
			_p = _room.get_node_or_null("Player")
		return false
	if _phase == 0:
		_p.set_physics_process(false)
		_p.set_process(false)
		_spr = _p.sprite
		_cam.zoom = Vector2(3.0, 3.0)
		_cam.make_current()
		_phase = 1
		return false
	_cam.global_position = _p.global_position + Vector2(0, -6)
	if _f % 4 != 0:
		return false
	if _armed != "":
		_shot(_armed)        # captura a pose setada no tick anterior (ja renderizou)
		_armed = ""
	if _i >= _seq.size():
		print("WALKCAP: %d shots ✓" % _shots)
		quit(0)
		return true
	var anim: String = _seq[_i][0]
	var fr: int = _seq[_i][1]
	if _spr.sprite_frames and _spr.sprite_frames.has_animation(anim):
		_spr.animation = anim
		_spr.frame = fr
		_spr.pause()
		_armed = "%s_%d" % [anim, fr]
	_i += 1
	return false

func _shot(tag: String) -> void:
	var img := get_root().get_texture().get_image()
	if img == null:
		print("WALKCAP: viewport sem imagem (", tag, ")")
		return
	var path := _out + "walk_%s.png" % tag
	if img.save_png(ProjectSettings.globalize_path(path)) == OK:
		_shots += 1
		print("shot -> ", path)

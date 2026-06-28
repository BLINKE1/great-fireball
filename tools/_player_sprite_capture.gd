extends SceneTree
## _player_sprite_capture.gd — instancia o player real e captura cada anim com a
## arte nova (soph_hd dream-rig). Mostra o game feel.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/_player_sprite_capture.gd
const ANIMS := ["idle", "walk", "run", "jump", "fall", "hurt", "cast_1", "slash_1"]
var _p: Node
var _spr: AnimatedSprite2D
var _f := 0
var _i := 0
var _ready := false
var _out := "res://tools/rig3d/out/player_ingame/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_size(Vector2i(240, 320))
	var bg := ColorRect.new()
	bg.color = Color(0.42, 0.45, 0.52); bg.size = Vector2(2000, 2000)
	bg.position = Vector2(-1000, -1000); get_root().add_child(bg)
	var ps := load("res://scenes/player/player.tscn")
	if ps == null: push_error("[cap] sem player.tscn"); quit(1); return
	_p = ps.instantiate(); get_root().add_child(_p)
	# camera propria centrada no player, zoom pra mostrar a maga
	var cam := Camera2D.new(); cam.zoom = Vector2(2.4, 2.4); cam.position = Vector2(0, -30)
	_p.add_child(cam); cam.make_current()

func _process(_d: float) -> bool:
	_f += 1
	if not _ready:
		if _f < 8: return false
		_spr = _p.get_node_or_null("Sprite2D")
		if _spr == null: push_error("[cap] sem Sprite2D"); quit(1); return true
		# congela fisica/logica pra so mostrar a pose
		_p.set_physics_process(false); _p.set_process(false)
		_ready = true
		print("[cap] anims do player: ", _spr.sprite_frames.get_animation_names())
	if _i >= ANIMS.size():
		quit(0); return true
	var a: String = ANIMS[_i]
	if _spr.sprite_frames.has_animation(a):
		_spr.play(a)
		# pega o frame do meio da anim
		var nf := _spr.sprite_frames.get_frame_count(a)
		_spr.frame = nf / 2
		_spr.stop()
	await_capture(a)
	return false

func await_capture(a: String) -> void:
	# captura no frame seguinte (deixa desenhar)
	if _f % 4 == 0:
		var img := get_root().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(_out + "%02d_%s.png" % [_i, a]))
		print("[cap] ", a)
		_i += 1

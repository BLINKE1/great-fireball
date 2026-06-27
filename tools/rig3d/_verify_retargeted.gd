extends SceneTree
## _verify_retargeted.gd — confere que o .glb exportado tem a anim embutida e a
## renderiza em 3/4 (toca a propria AnimationPlayer do glb, sem retarget).
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/_verify_retargeted.gd -- idle
const RES := Vector2i(560, 820)
const FRAMES := 12
const AZ := 315.0
const EL := 7.0
var _ts: Skeleton3D
var _ap: AnimationPlayer
var _cam: Camera3D
var _len := 1.0
var _animname := ""
var _f := 0
var _i := 0
var _ready := false
var _out := ""

func _initialize() -> void:
	var which := "idle"
	var uargs := OS.get_cmdline_user_args()
	if uargs.size() > 0: which = uargs[0]
	var glb := "res://tools/rig3d/in/soph_%s_retargeted.glb" % which
	_out = "res://tools/rig3d/out/verify_%s/" % which
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1,1,1); env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40,25,0); sun.light_energy = 0.9
	get_root().add_child(sun)

	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(glb), gs) != OK:
		push_error("[verify] falha glb"); quit(1); return
	var root := gd.generate_scene(gs); get_root().add_child(root)
	_ts = _find_skel(root)
	_ap = _find_ap(root)
	if _ts == null or _ap == null:
		push_error("[verify] sem skel/ap no glb -> anim NAO foi embutida!"); quit(1); return
	var names := _ap.get_animation_list()
	print("[verify] anims no glb: %s" % str(names))
	_animname = names[0]
	_len = _ap.get_animation(_animname).length
	_ap.play(_animname)
	print("[verify] tocando '%s' len=%.2fs" % [_animname, _len])
	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		var skt := _ts.global_transform
		var mn := Vector3(1e9,1e9,1e9); var mx := -mn
		for i in _ts.get_bone_count():
			var p: Vector3 = skt * _ts.get_bone_global_pose(i).origin
			mn = mn.min(p); mx = mx.max(p)
		var center := (mn+mx)*0.5; var h: float = (mx.y-mn.y)*1.35
		_cam.size = h
		var raz := deg_to_rad(AZ); var rel := deg_to_rad(EL)
		var dir := Vector3(sin(raz)*cos(rel), sin(rel), cos(raz)*cos(rel))
		_cam.look_at_from_position(center + dir*maxf(h*3.0,3.0), center, Vector3.UP)
		_cam.make_current()
	_f += 1
	if _i >= FRAMES: quit(0); return true
	_ap.seek((float(_i)/float(FRAMES))*_len, true)
	if _f % 3 == 0:
		get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + "f%02d.png" % _i))
		print("shot f%02d" % _i); _i += 1
	return false

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r: return r
	return null
func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r: return r
	return null

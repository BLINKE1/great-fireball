extends SceneTree
## render_player_sheet.gd — renderiza N frames de uma anim do glb retargetado com
## CAMERA FIXA (enquadrada pela REST pose -> mesma escala/posicao em TODAS as
## anims), 3/4, fundo transparente. Saida pro pixel-bake -> soph_hd_*.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/render_player_sheet.gd -- idle 8
const RES := Vector2i(400, 768)   # ratio ~0.52 (=100x192 final, /4)
const AZ := 315.0
const EL := 7.0
var _ts: Skeleton3D
var _ap: AnimationPlayer
var _cam: Camera3D
var _len := 1.0
var _animname := ""
var _f := 0
var _i := 0
var _n := 8
var _t0 := 0.0
var _t1 := 1.0
var _ready := false
var _out := ""

func _initialize() -> void:
	var which := "idle"
	var uargs := OS.get_cmdline_user_args()
	if uargs.size() > 0: which = uargs[0]
	if uargs.size() > 1: _n = int(uargs[1])
	if uargs.size() > 2: _t0 = float(uargs[2])   # fracao inicial da anim (0..1)
	if uargs.size() > 3: _t1 = float(uargs[3])   # fracao final da anim (0..1)
	var glb := "res://tools/rig3d/in/soph_%s_retargeted.glb" % which
	_out = "res://tools/rig3d/out/player_sheet/%s/" % which
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_size(RES)
	get_root().size = RES
	get_root().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1,1,1); env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40,25,0); sun.light_energy = 0.9
	get_root().add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-15,200,0); fill.light_energy = 0.45
	get_root().add_child(fill)

	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(glb), gs) != OK:
		push_error("[sheet] falha glb"); quit(1); return
	var root := gd.generate_scene(gs); get_root().add_child(root)
	_ts = _find_skel(root); _ap = _find_ap(root)
	if _ts == null or _ap == null:
		push_error("[sheet] sem skel/ap"); quit(1); return
	_animname = _ap.get_animation_list()[0]
	_len = _ap.get_animation(_animname).length

	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ap.play(_animname)
	print("[sheet] %s anim=%s len=%.2f n=%d" % [which, _animname, _len, _n])
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		# CAMERA FIXA HARDCODED (medida do idle) -> enquadramento IDENTICO em todas
		# as anims = escala consistente. Personagem anima dentro do frame fixo.
		var visible := 1.5074
		var c := Vector3(0.0048, 0.7123, 0.1122)
		_cam.size = visible
		var raz := deg_to_rad(AZ); var rel := deg_to_rad(EL)
		var dir := Vector3(sin(raz)*cos(rel), sin(rel), cos(raz)*cos(rel))
		_cam.look_at_from_position(c + dir*maxf(visible*3.0,3.0), c, Vector3.UP)
		_cam.make_current()
	_f += 1
	if _i >= _n: quit(0); return true
	# amostra _n frames na janela [_t0,_t1]; wrap (fmod) pra janelas > 1.0 darem
	# a volta no loop em vez de clampar no ultimo frame
	var frac: float = _t0 + (float(_i)/float(_n)) * (_t1 - _t0)
	var t: float = fmod(frac * _len, _len)
	_ap.seek(t, true)
	if _f % 3 == 0:
		get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + "f%02d.png" % _i))
		_i += 1
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

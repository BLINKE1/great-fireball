extends SceneTree
## render_walk_loop.gd — igual ao render_player_sheet MAS costura o LOOP em espaco
## de POSE (rotacao dos ossos), nao pixels. O walking.fbx da Mixamo e curto e NAO
## fecha o ciclo -> a costura ta na fonte. Aqui geramos n frames + B extras
## (continuando o movimento) e fazemos cross-fade da cabeca do ciclo com a
## continuacao um loop adiante -> o frame final casa suave com o inicial.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/render_walk_loop.gd -- walk 31 0.065 0.42 6
const RES := Vector2i(400, 768)
const AZ := 315.0
const EL := 7.0
var _ts: Skeleton3D
var _ap: AnimationPlayer
var _cam: Camera3D
var _len := 1.0
var _n := 31
var _t0 := 0.065
var _t1 := 0.42
var _blend := 6          # frames de cross-fade na cabeca do ciclo
var _animname := ""
var _out := ""
var _ready := false
var _phase := 0          # 0 = amostra poses, 1 = renderiza
var _samp := 0
var _rf := 0
var _i := 0
var _base: Array = []     # n+blend PackedFloat32Array (quats crus, continuos)
var _loop: Array = []     # n PackedFloat32Array (com loop costurado)

func _initialize() -> void:
	var u := OS.get_cmdline_user_args()
	var which := "walk"
	if u.size() > 0: which = u[0]
	if u.size() > 1: _n = int(u[1])
	if u.size() > 2: _t0 = float(u[2])
	if u.size() > 3: _t1 = float(u[3])
	if u.size() > 4: _blend = int(u[4])
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

	var glb := "res://tools/rig3d/in/soph_%s_retargeted.glb" % which
	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(glb), gs) != OK:
		push_error("[loop] falha glb"); quit(1); return
	var root := gd.generate_scene(gs); get_root().add_child(root)
	_ts = _find_skel(root); _ap = _find_ap(root)
	if _ts == null or _ap == null: push_error("[loop] sem skel/ap"); quit(1); return
	_animname = _ap.get_animation_list()[0]
	_len = _ap.get_animation(_animname).length
	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ap.play(_animname)
	print("[loop] %s anim=%s len=%.2f n=%d win=[%.3f,%.3f] blend=%d" % [which,_animname,_len,_n,_t0,_t1,_blend])
	_ready = true

func _sample_time(idx: int) -> float:
	# idx in [0, n+blend): continua o movimento alem de t1 pra ter a "continuacao"
	var frac: float = _t0 + (float(idx) / float(_n)) * (_t1 - _t0)
	return fmod(frac * _len, _len)

func _read_pose() -> PackedFloat32Array:
	var pv := PackedFloat32Array()
	for b in _ts.get_bone_count():
		var q := _ts.get_bone_pose_rotation(b)
		pv.append(q.x); pv.append(q.y); pv.append(q.z); pv.append(q.w)
	return pv

func _apply_pose(pv: PackedFloat32Array) -> void:
	for b in _ts.get_bone_count():
		var o := b * 4
		_ts.set_bone_pose_rotation(b, Quaternion(pv[o], pv[o+1], pv[o+2], pv[o+3]))
	_ts.force_update_all_bone_transforms()

func _blend_poses(a: PackedFloat32Array, b: PackedFloat32Array, t: float) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	var bones := _ts.get_bone_count()
	for i in bones:
		var k := i * 4
		var qa := Quaternion(a[k], a[k+1], a[k+2], a[k+3])
		var qb := Quaternion(b[k], b[k+1], b[k+2], b[k+3])
		var qc := qa.slerp(qb, t)
		o.append(qc.x); o.append(qc.y); o.append(qc.z); o.append(qc.w)
	return o

func _build_loop() -> void:
	# cross-fade: os primeiros _blend frames da cabeca recebem a continuacao
	# (frame i+n) -> o fim do ciclo casa com o comeco. Resto = base cru.
	for i in _n:
		if i < _blend:
			# alpha=1 no i=0 (loop[0] == continuacao _base[n] -> wrap vira 1 passo
			# consecutivo), easing suave ate 0 no fim da regiao de blend.
			var alpha: float = 1.0 - smoothstep(0.0, float(_blend), float(i))
			_loop.append(_blend_poses(_base[i], _base[i + _n], alpha))
		else:
			_loop.append(_base[i])
	# metrica de costura
	var cons := 0.0
	for i in _n - 1: cons += _pdist(_loop[i], _loop[i+1])
	cons /= (_n - 1)
	var seam := _pdist(_loop[_n-1], _loop[0])
	print("[loop] costura FINAL wrap[%d->0]=%.5f  consecutiva=%.5f  (%.2fx)" % [_n-1, seam, cons, seam/cons])

func _pdist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for k in a.size():
		var d: float = a[k] - b[k]
		s += d * d
	return s

func _process(_d: float) -> bool:
	if not _ready: return false
	if _rf == 0:
		var visible := 1.5074
		var c := Vector3(0.0048, 0.7123, 0.1122)
		_cam.size = visible
		var raz := deg_to_rad(AZ); var rel := deg_to_rad(EL)
		var dir := Vector3(sin(raz)*cos(rel), sin(rel), cos(raz)*cos(rel))
		_cam.look_at_from_position(c + dir*maxf(visible*3.0,3.0), c, Vector3.UP)
		_cam.make_current()
	_rf += 1

	if _phase == 0:
		# amostra n+blend poses cruas (continuas)
		if _samp < _n + _blend:
			_ap.seek(_sample_time(_samp), true)
			_base.append(_read_pose())
			_samp += 1
			return false
		_build_loop()
		_ap.active = false   # para de sobrescrever as poses que eu aplico na mao
		_phase = 1
		return false

	# phase 1: aplica pose costurada e renderiza (1 render a cada 2 ticks pra estabilizar)
	if _i >= _n: quit(0); return true
	if _rf % 2 == 0:
		_apply_pose(_loop[_i])
	else:
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

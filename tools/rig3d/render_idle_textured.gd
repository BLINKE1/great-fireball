extends SceneTree
## render_idle_textured.gd — IDLE do Mixamo na Soph texturizada+rigada.
## Retarget por CÓPIA LOCAL direta (os dois sao Mixamo padrao, mesmo rest -> fiel,
## conserta o braco torto do metodo global). Enquadra pelos ossos. 3/4 colorido.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/render_idle_textured.gd
const SOPH := "res://tools/rig3d/in/soph_textured_rigged.glb"
const ANIMFBX := "res://assets/mixamo/idle.fbx"
const OUT  := "res://tools/rig3d/out/idle_tex/"
const RES  := Vector2i(560, 820)
const FRAMES := 12
const AZ := 315.0
const EL := 7.0
const ARM_ADD := 22.0   # graus de aducao p/ trazer os cotovelos pra perto do tronco

var _ts: Skeleton3D
var _ms: Skeleton3D
var _ap: AnimationPlayer
var _animname := ""
var _rig: Node3D
var _cam: Camera3D
var _len := 1.0
var _f := 0
var _i := 0
var _ready := false
var _map: Dictionary = {}
var _hips := -1
var _hips_home := Vector3.ZERO

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1,1,1); env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,25,0); sun.light_energy = 0.9; sun.shadow_enabled = false
	get_root().add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15,200,0); fill.light_energy = 0.45; fill.shadow_enabled = false
	get_root().add_child(fill)

	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(SOPH), gs) != OK:
		push_error("[idle] falha soph"); quit(1); return
	_rig = gd.generate_scene(gs); get_root().add_child(_rig)
	_ts = _find_skel(_rig)

	var wd := FBXDocument.new(); var ws := FBXState.new()
	if wd.append_from_file(ProjectSettings.globalize_path(ANIMFBX), ws) != OK:
		push_error("[idle] falha anim"); quit(1); return
	var mix := wd.generate_scene(ws); get_root().add_child(mix)
	_ms = _find_skel(mix)
	for mi in mix.find_children("*","MeshInstance3D",true,false):
		(mi as MeshInstance3D).visible = false
	_ap = _find_ap(mix)
	if _ts == null or _ms == null or _ap == null:
		push_error("[idle] faltou skel/ap"); quit(1); return
	var bestn := -1
	for a in _ap.get_animation_list():
		var n := _ap.get_animation(a).get_track_count()
		if n > bestn: bestn = n; _animname = a
	_len = _ap.get_animation(_animname).length
	_ap.play(_animname)

	# mapa por nome (ambos viram "mixamorig_X" no engine)
	for b in _ts.get_bone_count():
		var mb := _ms.find_bone(_ts.get_bone_name(b))
		if mb < 0: mb = _ms.find_bone(_ts.get_bone_name(b).replace(":", "_"))
		if mb >= 0: _map[b] = mb
	_hips = _ts.find_bone("mixamorig_Hips")
	if _hips < 0: _hips = _ts.find_bone("mixamorig:Hips")
	if _hips >= 0: _hips_home = _ts.get_bone_pose_position(_hips)
	print("[idle] anim=%s ossos=%d/%d" % [_animname, _map.size(), _ts.get_bone_count()])

	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		var skt := _ts.global_transform
		var mn := Vector3(1e9, 1e9, 1e9); var mx := -mn
		for i in _ts.get_bone_count():
			var p: Vector3 = skt * _ts.get_bone_global_pose(i).origin
			mn = mn.min(p); mx = mx.max(p)
		var center := (mn + mx) * 0.5
		var h: float = (mx.y - mn.y) * 1.35
		_cam.size = h
		var raz := deg_to_rad(AZ); var rel := deg_to_rad(EL)
		var dir := Vector3(sin(raz)*cos(rel), sin(rel), cos(raz)*cos(rel))
		_cam.look_at_from_position(center + dir*maxf(h*3.0,3.0), center, Vector3.UP)
		_cam.make_current()
	_f += 1
	if _i >= FRAMES:
		quit(0); return true
	_ap.seek((float(_i)/float(FRAMES))*_len, true)
	_retarget()
	if _f % 3 == 0:
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "f%02d.png" % _i))
		print("shot f%02d" % _i)
		_i += 1
	return false

func _retarget() -> void:
	# DESVIO local: aplica o movimento do driver (relativo ao rest DELE) sobre o
	# rest da Soph -> mantem ela em pe e corrige o quadril deitado.
	for b in _map:
		var mb: int = _map[b]
		var m_rest: Quaternion = _ms.get_bone_rest(mb).basis.get_rotation_quaternion()
		var m_pose: Quaternion = _ms.get_bone_pose_rotation(mb)
		var dev: Quaternion = m_rest.inverse() * m_pose
		var t_rest: Quaternion = _ts.get_bone_rest(b).basis.get_rotation_quaternion()
		_ts.set_bone_pose_rotation(b, t_rest * dev)
	if _hips >= 0:
		_ts.set_bone_pose_position(_hips, _hips_home)  # in-place
	# correcao: aduz os bracos (cotovelos pra perto do tronco) -- ombro largo do auto-rig
	_world_rot("mixamorig_LeftArm", Vector3(0,0,1), -ARM_ADD)
	_world_rot("mixamorig_RightArm", Vector3(0,0,1), ARM_ADD)

# aplica uma rotacao no MUNDO sobre a pose ATUAL do osso (depois do retarget)
func _world_rot(bone: String, axis: Vector3, deg: float) -> void:
	var b := _ts.find_bone(bone)
	if b < 0: return
	var r := Basis(axis.normalized(), deg_to_rad(deg))
	var cur := _ts.get_bone_global_pose(b).basis.orthonormalized()
	var par := _ts.get_bone_parent(b)
	var pg: Basis = (_ts.get_bone_global_pose(par).basis.orthonormalized()) if par >= 0 else Basis()
	_ts.set_bone_pose_rotation(b, (pg.inverse() * (r * cur)).get_rotation_quaternion())

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

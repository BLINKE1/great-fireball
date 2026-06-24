extends SceneTree
## retarget_walk.gd — RETARGET do walk do Mixamo (assets/mixamo/walking.fbx) pro
## rig da Soph (soph_rigged.fbx), renderizado em 3/4. Driver:
##   - a anim do Mixamo pilota o esqueleto do xbot (MS);
##   - p/ cada osso, copio o DESVIO (rest^-1 * pose) do xbot e aplico no rest da
##     Soph (TS): target_local = Trest * (Mrest^-1 * Mpose). Compensa rest pose.
##   - nomes batem: soph "Hips" <-> mixamo "mixamorig_Hips".
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/retarget_walk.gd
const SOPH := "res://tools/rig3d/in/soph_rigged.fbx"
const WALK := "res://assets/mixamo/walking.fbx"
const ANIM := "mixamo_com"
const OUT  := "res://tools/rig3d/out/retarget/"
const RES  := Vector2i(360, 512)
const FRAMES := 16
const AZ := 315.0
const EL := 8.0

var _ts: Skeleton3D     # target (Soph)
var _ms: Skeleton3D     # mixamo (xbot)
var _ap: AnimationPlayer
var _rig: Node3D
var _cam: Camera3D
var _len := 1.0
var _f := 0
var _i := 0
var _ready := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1); env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0); sun.light_energy = 1.6
	get_root().add_child(sun)

	# Soph (alvo) - renderiza
	var sd := FBXDocument.new(); var ss := FBXState.new()
	if sd.append_from_file(ProjectSettings.globalize_path(SOPH), ss) != OK:
		push_error("[rt] falha soph"); quit(1); return
	_rig = sd.generate_scene(ss); get_root().add_child(_rig)
	_ts = _find_skel(_rig)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.72,0.74,0.8)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat

	# Mixamo (driver) - escondido
	var wd := FBXDocument.new(); var ws := FBXState.new()
	if wd.append_from_file(ProjectSettings.globalize_path(WALK), ws) != OK:
		push_error("[rt] falha walk"); quit(1); return
	var mix := wd.generate_scene(ws); get_root().add_child(mix)
	_ms = _find_skel(mix)
	for mi in mix.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	_ap = _find_ap(mix)
	if _ts == null or _ms == null or _ap == null:
		push_error("[rt] faltou skel/anim ts=%s ms=%s ap=%s" % [_ts, _ms, _ap]); quit(1); return
	_len = _ap.get_animation(ANIM).length
	_ap.play(ANIM)

	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		var ab := _world_aabb(_rig)
		_rig.position = -ab.get_center()
		var h: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		_cam.size = h * 1.15
		var raz := deg_to_rad(AZ); var rel := deg_to_rad(EL)
		var dir := Vector3(sin(raz)*cos(rel), sin(rel), cos(raz)*cos(rel))
		_cam.look_at_from_position(dir * maxf(h*3.0, 3.0), Vector3.ZERO, Vector3.UP)
		_cam.make_current()
	_f += 1
	if _i >= FRAMES:
		quit(0); return true
	# poe o xbot no tempo t e copia o desvio pra Soph
	var t := (float(_i) / float(FRAMES)) * _len
	_ap.seek(t, true)
	_retarget()
	if _f % 3 == 0:
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "f%02d.png" % _i))
		print("shot f%02d t=%.2f" % [_i, t])
		_i += 1
	return false

func _retarget() -> void:
	for b in _ts.get_bone_count():
		var bn := _ts.get_bone_name(b)
		var mb := _ms.find_bone("mixamorig_" + bn)
		if mb < 0: continue
		var m_rest: Quaternion = _ms.get_bone_rest(mb).basis.get_rotation_quaternion()
		var m_pose: Quaternion = _ms.get_bone_pose_rotation(mb)
		var dev: Quaternion = m_rest.inverse() * m_pose
		var t_rest: Quaternion = _ts.get_bone_rest(b).basis.get_rotation_quaternion()
		_ts.set_bone_pose_rotation(b, t_rest * dev)

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

func _world_aabb(node: Node) -> AABB:
	var out := AABB(); var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first: out = box; first = false
		else: out = out.merge(box)
	return out

extends SceneTree
## retarget_walk_v2.gd — RETARGET v2 (transferencia de orientacao GLOBAL).
## Em vez de copiar o desvio LOCAL (v1 distorceu), transfere a rotacao GLOBAL que
## cada osso sofreu no Mixamo e reconstroi o pose local na Soph respeitando a
## hierarquia (pai antes do filho). Mais robusto a roll/eixo diferente.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/retarget_walk_v2.gd
const SOPH := "res://tools/rig3d/in/soph_rigged.fbx"
const WALK := "res://assets/mixamo/walking.fbx"
const ANIM := "mixamo_com"
const OUT  := "res://tools/rig3d/out/retarget_v2/"
const RES  := Vector2i(360, 512)
const FRAMES := 12
const AZ := 315.0
const EL := 8.0

var _ts: Skeleton3D
var _ms: Skeleton3D
var _ap: AnimationPlayer
var _rig: Node3D
var _cam: Camera3D
var _len := 1.0
var _f := 0
var _i := 0
var _ready := false
# ordem de processamento (pai antes do filho)
var _order: Array[int] = []
var _map: Dictionary = {}   # bone soph -> bone mixamo

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1,1,1); env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,35,0); sun.light_energy = 1.6
	get_root().add_child(sun)

	var sd := FBXDocument.new(); var ss := FBXState.new()
	if sd.append_from_file(ProjectSettings.globalize_path(SOPH), ss) != OK:
		push_error("[v2] falha soph"); quit(1); return
	_rig = sd.generate_scene(ss); get_root().add_child(_rig)
	_ts = _find_skel(_rig)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.72,0.74,0.8)
	for mi in _rig.find_children("*","MeshInstance3D",true,false):
		(mi as MeshInstance3D).material_override = mat

	var wd := FBXDocument.new(); var ws := FBXState.new()
	if wd.append_from_file(ProjectSettings.globalize_path(WALK), ws) != OK:
		push_error("[v2] falha walk"); quit(1); return
	var mix := wd.generate_scene(ws); get_root().add_child(mix)
	_ms = _find_skel(mix)
	for mi in mix.find_children("*","MeshInstance3D",true,false):
		(mi as MeshInstance3D).visible = false
	_ap = _find_ap(mix)
	if _ts == null or _ms == null or _ap == null:
		push_error("[v2] faltou skel/anim"); quit(1); return
	_len = _ap.get_animation(ANIM).length
	_ap.play(ANIM)

	# mapa soph->mixamo e ordem por indice (pai antes do filho ja vale: idx cresce)
	for b in _ts.get_bone_count():
		var mb := _ms.find_bone("mixamorig_" + _ts.get_bone_name(b))
		if mb >= 0:
			_map[b] = mb
		_order.append(b)

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
		_cam.look_at_from_position(dir*maxf(h*3.0,3.0), Vector3.ZERO, Vector3.UP)
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
	# transfere orientacao GLOBAL osso a osso (pai antes do filho)
	for b in _order:
		if not _map.has(b):
			continue
		var mb: int = _map[b]
		var m_grest: Basis = _ms.get_bone_global_rest(mb).basis
		var m_gpose: Basis = _ms.get_bone_global_pose(mb).basis
		var world_delta: Basis = m_gpose * m_grest.inverse()
		var t_grest: Basis = _ts.get_bone_global_rest(b).basis
		var desired: Basis = world_delta * t_grest
		var par := _ts.get_bone_parent(b)
		var p_g: Basis = _ts.get_bone_global_pose(par).basis if par >= 0 else Basis()
		var new_local: Basis = p_g.inverse() * desired
		_ts.set_bone_pose_rotation(b, new_local.get_rotation_quaternion())

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
	for c in node.find_children("*","MeshInstance3D",true,false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first: out = box; first = false
		else: out = out.merge(box)
	return out

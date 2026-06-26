extends SceneTree
## render_walk_textured.gd — retarget do walk do Mixamo na Soph TEXTURIZADA+RIGADA
## (soph_textured_rigged.glb) e render 3/4 colorido. Como os dois sao Mixamo, o
## retarget bate quase perfeito.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/render_walk_textured.gd
const SOPH := "res://tools/rig3d/in/soph_textured_rigged.glb"
const WALK := "res://assets/mixamo/walking.fbx"
const ANIM := "mixamo_com"
const OUT  := "res://tools/rig3d/out/walk_tex/"
const RES  := Vector2i(600, 880)
const FRAMES := 14
const AZ := 315.0
const EL := 7.0

var _ts: Skeleton3D
var _ms: Skeleton3D
var _ap: AnimationPlayer
var _rig: Node3D
var _cam: Camera3D
var _len := 1.0
var _f := 0
var _i := 0
var _ready := false
var _order: Array[int] = []
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
		push_error("[wt] falha soph"); quit(1); return
	_rig = gd.generate_scene(gs); get_root().add_child(_rig)
	_ts = _find_skel(_rig)

	var wd := FBXDocument.new(); var ws := FBXState.new()
	if wd.append_from_file(ProjectSettings.globalize_path(WALK), ws) != OK:
		push_error("[wt] falha walk"); quit(1); return
	var mix := wd.generate_scene(ws); get_root().add_child(mix)
	_ms = _find_skel(mix)
	for mi in mix.find_children("*","MeshInstance3D",true,false):
		(mi as MeshInstance3D).visible = false
	_ap = _find_ap(mix)
	if _ts == null or _ms == null or _ap == null:
		push_error("[wt] faltou skel/ap"); quit(1); return
	_len = _ap.get_animation(ANIM).length
	_ap.play(ANIM)

	# mapa: "mixamorig:X" (target) -> "mixamorig_X" (driver)
	var depth := {}
	for b in _ts.get_bone_count():
		var nm := _ts.get_bone_name(b)
		var mb := _ms.find_bone(nm.replace(":", "_"))
		if mb >= 0: _map[b] = mb
		var d := 0; var p := _ts.get_bone_parent(b)
		while p >= 0: d += 1; p = _ts.get_bone_parent(p)
		depth[b] = d
	_order = []
	for b in _ts.get_bone_count(): _order.append(b)
	_order.sort_custom(func(a,c): return depth[a] < depth[c])
	_hips = _ts.find_bone("mixamorig:Hips")
	if _hips >= 0: _hips_home = _ts.get_bone_pose_position(_hips)
	print("[wt] ossos mapeados: %d/%d" % [_map.size(), _ts.get_bone_count()])

	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		# enquadra pelos OSSOS (mundo) -- AABB de mesh skinado engana c/ a escala 0.01
		var skt := _ts.global_transform
		var mn := Vector3(1e9, 1e9, 1e9); var mx := -mn
		for i in _ts.get_bone_count():
			var p: Vector3 = skt * _ts.get_bone_global_pose(i).origin
			mn = mn.min(p); mx = mx.max(p)
		var center := (mn + mx) * 0.5
		var h: float = (mx.y - mn.y) * 1.5
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
	# DESVIO local (igual ao idle): T_rest * (M_rest^-1 * M_pose) -> fiel, em pe
	for b in _map:
		var mb: int = _map[b]
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
	for c in node.find_children("*","MeshInstance3D",true,false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first: out = box; first = false
		else: out = out.merge(box)
	return out

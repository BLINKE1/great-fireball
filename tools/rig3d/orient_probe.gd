extends SceneTree
## orient_probe.gd — renderiza o soph_rigged.fbx (bind pose) de 8 azimutes
## pra DESCOBRIR pra que lado a Soph encara (frente = rosto/oculos visivel).
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/orient_probe.gd
const FBX := "res://tools/rig3d/in/soph_rigged.fbx"
const OUT := "res://tools/rig3d/out/orient/"
const RES := Vector2i(300, 420)
const AZS := [0, 45, 90, 135, 180, 225, 270, 315]

var _rig: Node3D
var _cam: Camera3D
var _center := Vector3.ZERO
var _dist := 5.0
var _size := 2.0
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
	env.ambient_light_color = Color(1, 1, 1); env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0); sun.light_energy = 1.5
	get_root().add_child(sun)

	var doc := FBXDocument.new(); var st := FBXState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(FBX), st) != OK:
		push_error("[orient] falha FBX"); quit(1); return
	_rig = doc.generate_scene(st)
	get_root().add_child(_rig)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.74,0.76,0.82)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		var ab := _world_aabb(_rig)
		_center = ab.get_center()
		_size = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		_cam.size = _size * 1.12
		_dist = maxf(_size * 3.0, 3.0)
	_f += 1
	if _i >= AZS.size():
		quit(0); return true
	var az := deg_to_rad(float(AZS[_i]))
	var el := deg_to_rad(8.0)
	# orbita em torno de Y (up), olhando o centro
	var dir := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	_cam.look_at_from_position(_center + dir * _dist, _center, Vector3.UP)
	if _f % 3 == 0:
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "az_%03d.png" % AZS[_i]))
		print("shot az=", AZS[_i])
		_i += 1
	return false

func _world_aabb(node: Node) -> AABB:
	var out := AABB(); var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first: out = box; first = false
		else: out = out.merge(box)
	return out

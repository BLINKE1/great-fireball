extends SceneTree
## render_textured.gd — renderiza o soph_dressed_mesh.glb TEXTURIZADO em varios
## azimutes (3/4 etc.), mantendo o material real (cores da Soph). Fundo alpha.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/render_textured.gd
const GLB := "res://tools/rig3d/in/soph_dressed_mesh.glb"
const OUT := "res://tools/rig3d/out/textured/"
const RES := Vector2i(512, 768)
const AZS := [0, 45, 315, 90, 180]
const EL := 8.0

var _rig: Node3D
var _cam: Camera3D
var _center := Vector3.ZERO
var _dist := 5.0
var _up := Vector3.UP
var _side := Vector3(1,0,0)
var _fwd := Vector3(0,0,1)
var _f := 0
var _i := 0
var _ready := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true
	# luz bem chapada p/ a textura/albedo ler fiel
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1,1,1); env.ambient_light_energy = 1.15
	var we := WorldEnvironment.new(); we.environment = env; get_root().add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,30,0); sun.light_energy = 1.0
	sun.shadow_enabled = false
	get_root().add_child(sun)

	var doc := FBXDocument.new()  # placeholder
	var gdoc := GLTFDocument.new(); var st := GLTFState.new()
	if gdoc.append_from_file(ProjectSettings.globalize_path(GLB), st) != OK:
		push_error("[tex] falha GLB"); quit(1); return
	_rig = gdoc.generate_scene(st)
	get_root().add_child(_rig)
	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		var ab := _world_aabb(_rig)
		var s := ab.size
		var up_i := 1
		if s.z >= s.x and s.z >= s.y: up_i = 2
		elif s.x >= s.y and s.x >= s.z: up_i = 0
		var axes := [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]
		_up = axes[up_i]
		var rem: Array = []
		for k in 3:
			if k != up_i: rem.append(axes[k])
		_side = rem[0]; _fwd = rem[1]
		_center = ab.get_center()
		var h: float = maxf(s.x, maxf(s.y, s.z))
		_cam.size = h * 1.12
		_dist = maxf(h*3.0, 3.0)
		print("[tex] up=", _up, " aabb=", ab)
	_f += 1
	if _i >= AZS.size():
		quit(0); return true
	var raz := deg_to_rad(float(AZS[_i])); var rel := deg_to_rad(EL)
	var dir: Vector3 = _side*(sin(raz)*cos(rel)) + _fwd*(cos(raz)*cos(rel)) + _up*sin(rel)
	_cam.look_at_from_position(_center + dir*_dist, _center, _up)
	if _f % 4 == 0:
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "az_%03d.png" % AZS[_i]))
		print("shot az=", AZS[_i])
		_i += 1
	return false

func _world_aabb(node: Node) -> AABB:
	var out := AABB(); var first := true
	for c in node.find_children("*","MeshInstance3D",true,false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first: out = box; first = false
		else: out = out.merge(box)
	return out

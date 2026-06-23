extends SceneTree
## turntable_godot.gd — DE-RISK do pipeline Soph3D SEM Blender/Mixamo.
## Carrega o mesh estatico (in/soph_mesh.glb) em runtime via GLTFDocument,
## poe uma camera 3/4 ortho + luz, e RENDERIZA varios azimutes pra PNG.
## Prova a metade-chave da tese: "3D TEM o lado oculto -> gira a camera e sai
## 3/4 consistente em todo angulo" (mata o drift). Nao precisa de rig.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/turntable_godot.gd
const GLB  := "res://tools/rig3d/in/soph_mesh.glb"
const OUT  := "res://tools/rig3d/out/turn/"
const RES  := Vector2i(512, 768)
# azimutes a capturar (0 = frente; 35/-35 = os 3/4 que o pipeline quer)
const AZ   := [0, 35, -35, 90, -90, 145, 180, 215]
const EL   := 10.0   # elevacao (graus)

var _pivot: Node3D
var _cam: Camera3D
var _aabb: AABB
var _i := 0
var _f := 0
var _ready := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)

	# fundo + ambiente flat (sem isso o mesh sai preto no headless)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	get_root().add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.6
	get_root().add_child(sun)

	# importa o GLB em runtime
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(GLB), st)
	if err != OK:
		push_error("[turntable] falha ao ler GLB: %d" % err); quit(1); return
	var scene := doc.generate_scene(st)
	if scene == null:
		push_error("[turntable] generate_scene null"); quit(1); return

	_pivot = Node3D.new()
	get_root().add_child(_pivot)
	_pivot.add_child(scene)

	_aabb = _world_aabb(scene)
	# recentra o mesh no pivo (pra girar em torno do proprio eixo)
	scene.position = -_aabb.get_center()

	var h := maxf(_aabb.size.y, 0.001)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = h * 1.2
	get_root().add_child(_cam)
	var rel := deg_to_rad(EL)
	var dist := maxf(h * 3.0, 2.0)
	_cam.position = Vector3(0, sin(rel) * dist, cos(rel) * dist)
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	_cam.make_current()
	_ready = true

func _process(_d: float) -> bool:
	if not _ready:
		return false
	_f += 1
	if _i >= AZ.size():
		quit(0); return true
	# gira o mesh (nao a camera) -> camera fixa, vemos todos os lados
	_pivot.rotation_degrees = Vector3(0, float(AZ[_i]), 0)
	# espera o viewport desenhar antes de capturar
	if _f % 4 == 0:
		var img := get_root().get_texture().get_image()
		var tag := "az_%+03d" % int(AZ[_i])
		img.save_png(ProjectSettings.globalize_path(OUT + tag + ".png"))
		print("shot -> ", tag)
		_i += 1
	return false

func _world_aabb(node: Node) -> AABB:
	var out: AABB = AABB()
	var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first:
			out = box; first = false
		else:
			out = out.merge(box)
	if first:
		out = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
	return out

extends SceneTree
## turntable_godot.gd — DE-RISK do pipeline Soph3D SEM Blender/Mixamo.
## Carrega o mesh estatico (in/soph_mesh.glb) em runtime via GLTFDocument,
## poe camera 3/4 ortho + luz, e RENDERIZA varios azimutes pra PNG com FUNDO
## TRANSPARENTE (alpha) -> e o alpha, nao o contorno, que mata a mescla com
## fundo no sprite sheet. Em cada angulo gera 2 versoes:
##   - plain : so o mesh (estilo "pintado macio")
##   - hk    : + contorno preto inverted-hull (grow + cull_front) estilo Hollow Knight
## Prova a metade-chave da tese: mesma geometria girando -> 3/4 consistente,
## zero drift. Nao precisa de rig.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/turntable_godot.gd
const GLB  := "res://tools/rig3d/in/soph_mesh.glb"
const OUT  := "res://tools/rig3d/out/turn/"
const RES  := Vector2i(512, 768)
const AZ   := [0, 35, -35, 90]
const EL   := 8.0                   # elevacao (graus)
const OUTLINE := 0.012

var _pivot: Node3D
var _cam: Camera3D
var _eye := Vector3.ZERO
var _cam_oriented := false
var _outline_nodes: Array[MeshInstance3D] = []
var _aabb: AABB
var _i := 0
var _phase := 0   # 0 = plain, 1 = hk
var _f := 0
var _ready := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true   # alpha limpo no get_image()

	# ambiente flat SO p/ iluminar (sem cor de fundo -> fica transparente)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	get_root().add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.5
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
	scene.position = -_aabb.get_center()   # recentra no pivo

	# casca preta (inverted-hull) por mesh -> contorno HK, escondida por padrao
	if OUTLINE > 0.0:
		var blk := StandardMaterial3D.new()
		blk.albedo_color = Color.BLACK
		blk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blk.cull_mode = BaseMaterial3D.CULL_FRONT   # so as faces de tras = silhueta
		blk.grow = true
		blk.grow_amount = OUTLINE
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var src := mi as MeshInstance3D
			if src.mesh == null:
				continue
			var hull := MeshInstance3D.new()
			hull.mesh = _with_normals(src.mesh)   # grow precisa de normais
			hull.material_override = blk
			hull.transform = src.transform
			hull.visible = false
			src.get_parent().add_child(hull)
			_outline_nodes.append(hull)

	var h := maxf(_aabb.size.y, 0.001)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = h * 1.08
	get_root().add_child(_cam)
	var rel := deg_to_rad(EL)
	var dist := maxf(h * 3.0, 2.0)
	_eye = Vector3(0, sin(rel) * dist, cos(rel) * dist)
	_cam.make_current()
	_ready = true

func _process(_d: float) -> bool:
	if not _ready:
		return false
	if not _cam_oriented:
		# look_at exige estar no tree -> orienta no 1o frame
		_cam.look_at_from_position(_eye, Vector3.ZERO, Vector3.UP)
		_cam_oriented = true
	_f += 1
	if _i >= AZ.size():
		quit(0); return true
	_pivot.rotation_degrees = Vector3(0, float(AZ[_i]), 0)
	var hk := _phase == 1
	for n in _outline_nodes:
		n.visible = hk
	# espera o viewport desenhar antes de capturar
	if _f % 4 == 0:
		var img := get_root().get_texture().get_image()
		var tag := "az_%+03d_%s" % [int(AZ[_i]), ("hk" if hk else "plain")]
		img.save_png(ProjectSettings.globalize_path(OUT + tag + ".png"))
		print("shot -> ", tag)
		if _phase == 0:
			_phase = 1
		else:
			_phase = 0
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

# recalcula normais (a casca inverted-hull precisa delas pra crescer)
func _with_normals(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var stool := SurfaceTool.new()
		stool.create_from(mesh, s)
		stool.generate_normals()
		stool.commit(out)
	return out

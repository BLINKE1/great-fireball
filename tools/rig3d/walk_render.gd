extends SceneTree
## walk_render.gd — carrega o soph_rigged.fbx, monta um WALK CYCLE procedural
## (sem anim embutida) e renderiza N frames de uma camera 3/4 (alpha).
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/walk_render.gd
const FBX := "res://tools/rig3d/in/soph_rigged.fbx"
const OUT := "res://tools/rig3d/out/walk/"
const RES := Vector2i(360, 512)
const FRAMES := 12
const AZ := 35.0     # azimute 3/4
const EL := 8.0      # elevacao

# walk procedural: rotacoes em torno dos eixos do MUNDO (convertidas p/ local do
# osso) -> independe do roll/orientacao local do bone. Soph encara +/-Z, up=Y,
# lateral=X. Passo frente/tras = girar em torno de X; baixar braco = em torno de Z.
const WX := Vector3(1, 0, 0)
const WZ := Vector3(0, 0, 1)
const A_THIGH := 25.0
const A_KNEE  := 45.0
const A_ARM   := 18.0
const ARM_LOWER := 68.0
const BOB     := 0.02

var _pivot: Node3D
var _rig: Node3D
var _sk: Skeleton3D
var _cam: Camera3D
var _aabb: AABB
var _up := Vector3.UP
var _f := 0
var _i := 0
var _ready := false
var _hips_home := Vector3.ZERO

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(RES)
	get_root().transparent_bg = true

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new(); we.environment = env
	get_root().add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0); sun.light_energy = 1.6
	get_root().add_child(sun)

	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(FBX), st) != OK:
		push_error("[walk] falha FBX"); quit(1); return
	var scene := doc.generate_scene(st)
	if scene == null:
		push_error("[walk] scene null"); quit(1); return

	_pivot = Node3D.new(); get_root().add_child(_pivot)
	_rig = scene; _pivot.add_child(_rig)
	_sk = _find_skel(_rig)
	if _sk == null:
		push_error("[walk] sem Skeleton3D"); quit(1); return

	# material visivel (texturas estao fora do git) p/ ler a deformacao
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.74, 0.8)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_root().add_child(_cam)
	_ready = true

func _setup() -> void:
	# rodar SO no 1o _process: transforms ja propagados (world AABB valido)
	_aabb = _world_aabb(_rig)
	var s := _aabb.size
	var up_i := 1
	if s.z >= s.x and s.z >= s.y: up_i = 2
	elif s.x >= s.y and s.x >= s.z: up_i = 0
	var axes := [Vector3(1,0,0), Vector3(0,1,0), Vector3(0,0,1)]
	_up = axes[up_i]
	var rem: Array = []
	for k in 3:
		if k != up_i: rem.append(axes[k])
	var side: Vector3 = rem[0]; var fwd: Vector3 = rem[1]
	_rig.position = -_aabb.get_center()

	var h: float = maxf(s.x, maxf(s.y, s.z))
	_cam.size = h * 1.15
	var raz := deg_to_rad(AZ); var rel := deg_to_rad(EL)
	var dist: float = maxf(h * 3.0, 3.0)
	var dir: Vector3 = side * (sin(raz) * cos(rel)) - fwd * (cos(raz) * cos(rel)) + _up * sin(rel)
	_cam.look_at_from_position(dir * dist, Vector3.ZERO, _up)
	_cam.make_current()
	var hi := _sk.find_bone("Hips")
	if hi >= 0: _hips_home = _sk.get_bone_pose_position(hi)
	print("[walk] up=", _up, " worldAABB=", _aabb, " bones=", _sk.get_bone_count())

func _process(_d: float) -> bool:
	if not _ready: return false
	if _f == 0:
		_setup()
	_f += 1
	if _i >= FRAMES:
		quit(0); return true
	_pose(float(_i) / float(FRAMES))
	if _f % 3 == 0:
		var img := get_root().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "f%02d.png" % _i))
		print("shot f%02d" % _i)
		_i += 1
	return false

func _pose(p: float) -> void:
	var w := p * TAU
	# PERNAS: passo frente/tras em torno do eixo lateral do MUNDO (X), fases opostas
	_apply("LeftUpLeg",  _ax(WX,  A_THIGH * sin(w)))
	_apply("RightUpLeg", _ax(WX,  A_THIGH * sin(w + PI)))
	# JOELHO so dobra pra tras (sinal unico), maximo na passagem da perna p/ frente
	_apply("LeftLeg",  _ax(WX, -A_KNEE * maxf(0.0,  sin(w))))
	_apply("RightLeg", _ax(WX, -A_KNEE * maxf(0.0,  sin(w + PI))))
	# BRACOS: baixa (mundo Z, sinal oposto por lado) + balanca oposto a perna (X)
	_apply("LeftArm",  _ax(WX, A_ARM * sin(w + PI)) * _ax(WZ,  ARM_LOWER))
	_apply("RightArm", _ax(WX, A_ARM * sin(w))      * _ax(WZ, -ARM_LOWER))
	# BOB vertical (2x a frequencia do passo)
	var hi := _sk.find_bone("Hips")
	if hi >= 0:
		var off := Vector3.ZERO
		off.y = BOB * cos(2.0 * w)
		_sk.set_bone_pose_position(hi, _hips_home + off)

func _ax(axis: Vector3, deg: float) -> Basis:
	return Basis(axis.normalized(), deg_to_rad(deg))

# aplica uma rotacao R definida em coords do MUNDO no osso (converte p/ local
# usando o rest global do pai) -> robusto ao roll do bone.
func _apply(bone: String, r: Basis) -> void:
	var i := _sk.find_bone(bone)
	if i < 0: return
	var p := _sk.get_bone_parent(i)
	var par := _sk.get_bone_global_rest(p).basis if p >= 0 else Basis()
	var loc := _sk.get_bone_rest(i).basis
	var new_local := par.inverse() * r * par * loc
	_sk.set_bone_pose_rotation(i, new_local.get_rotation_quaternion())

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find_skel(c)
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
	if first: out = AABB(Vector3(-0.5,-0.5,-0.5), Vector3(1,1,1))
	return out

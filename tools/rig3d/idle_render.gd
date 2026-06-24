extends SceneTree
## idle_render.gd — IDLE procedural autoral no soph_rigged.fbx, render 3/4 (az=315).
## Respiracao (coluna) + bob + micro-cabeca + bracos baixos respirando. Sutil, em
## loop. (Sem ossos de cabelo/saia no rig -> jiggle fica p/ fase 2.)
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/idle_render.gd
const FBX := "res://tools/rig3d/in/soph_rigged.fbx"
const OUT := "res://tools/rig3d/out/idle/"
const RES := Vector2i(360, 512)
const FRAMES := 20
const AZ := 315.0
const EL := 8.0
const WX := Vector3(1, 0, 0)

# amplitudes (graus / unidades) — TUDO sutil
const BREATH := 2.2     # extensao da coluna
const HEADB  := 1.6     # contramovimento da cabeca
const ARMB   := 2.2     # bracos sobem/descem leve c/ respiracao
const BOB    := 0.010   # sobe/desce vertical
const SWAY   := 0.006   # leve troca de peso lateral

var _rig: Node3D
var _sk: Skeleton3D
var _cam: Camera3D
var _hips_home := Vector3.ZERO
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
	var doc := FBXDocument.new(); var st := FBXState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(FBX), st) != OK:
		push_error("[idle] falha FBX"); quit(1); return
	_rig = doc.generate_scene(st); get_root().add_child(_rig)
	_sk = _find_skel(_rig)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.72,0.74,0.8)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
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
		_cam.look_at_from_position(dir * maxf(h*3.0,3.0), Vector3.ZERO, Vector3.UP)
		_cam.make_current()
		var hi := _sk.find_bone("Hips")
		if hi >= 0: _hips_home = _sk.get_bone_pose_position(hi)
	_f += 1
	if _i >= FRAMES:
		quit(0); return true
	_pose(float(_i) / float(FRAMES))
	if _f % 3 == 0:
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "f%02d.png" % _i))
		print("shot f%02d" % _i)
		_i += 1
	return false

func _pose(p: float) -> void:
	var w := p * TAU
	var breath := sin(w)           # 1 ciclo de respiracao por loop
	# coluna: leve extensao distribuida (respiracao)
	_apply("Spine",  _ax(WX, BREATH * 0.5 * breath))
	_apply("Spine1", _ax(WX, BREATH * 0.7 * breath))
	_apply("Spine2", _ax(WX, BREATH * 0.5 * breath))
	# cabeca: contramovimento sutil p/ nao "afundar" o olhar
	_apply("Head", _ax(WX, -HEADB * breath))
	# bracos baixos (aim) + leve respiro
	var laim := _aim("LeftArm",  "LeftForeArm",  Vector3(-0.40, -1.0, 0.12))
	var raim := _aim("RightArm", "RightForeArm", Vector3( 0.40, -1.0, 0.12))
	_apply("LeftArm",  _ax(WX,  ARMB * breath) * laim)
	_apply("RightArm", _ax(WX,  ARMB * breath) * raim)
	# hips: bob (2x) + leve troca de peso lateral (1x)
	var hi := _sk.find_bone("Hips")
	if hi >= 0:
		var off := Vector3(SWAY * sin(w), BOB * 0.5 * (1.0 - cos(w)), 0.0)
		_sk.set_bone_pose_position(hi, _hips_home + off)

func _ax(axis: Vector3, deg: float) -> Basis:
	return Basis(axis.normalized(), deg_to_rad(deg))

func _apply(bone: String, r: Basis) -> void:
	var i := _sk.find_bone(bone)
	if i < 0: return
	var p := _sk.get_bone_parent(i)
	var par := _sk.get_bone_global_rest(p).basis if p >= 0 else Basis()
	var loc := _sk.get_bone_rest(i).basis
	_sk.set_bone_pose_rotation(i, (par.inverse() * r * par * loc).get_rotation_quaternion())

func _aim(bone: String, child: String, target: Vector3) -> Basis:
	var bi := _sk.find_bone(bone); var ci := _sk.find_bone(child)
	if bi < 0 or ci < 0: return Basis()
	var a := _sk.get_bone_global_rest(bi).origin
	var b := _sk.get_bone_global_rest(ci).origin
	var cur := b - a
	if cur.length() < 1e-5: return Basis()
	return Basis(Quaternion(cur.normalized(), target.normalized()))

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
	return out

extends SceneTree
## export_retargeted_anim.gd — assa a anim Mixamo retargetada (por DESVIO) na Soph
## texturizada+rigada e EXPORTA um .glb com os keyframes nos ossos Mixamo.
## É a "anim PRO" pro PC importar na cena de cloth (substitui o placeholder
## procedural de braço aberto). Mesmo retarget dos render_*_textured.gd.
##
## Uso:
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/export_retargeted_anim.gd -- idle
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/export_retargeted_anim.gd -- walk
const SOPH := "res://tools/rig3d/in/soph_textured_rigged.glb"
const FPS := 30.0
const ARM_ADD := 22.0   # adução: tira o braço aberto (cotovelos pro tronco)

# anim -> { fbx, adduct } -- adduct=true so na locomocao (abaixa braco); combate
# (cast/slash com braco erguido) NAO aduz pra nao distorcer a pose do mocap.
const ANIMS := {
	"idle":  {"fbx": "res://assets/mixamo/idle.fbx",    "adduct": true},
	"walk":  {"fbx": "res://assets/mixamo/walking.fbx", "adduct": true},
	"run":   {"fbx": "res://assets/mixamo/running.fbx", "adduct": true},
	"jump":  {"fbx": "res://assets/mixamo/jump.fbx",    "adduct": true},
	"cast":  {"fbx": "res://assets/mixamo/cast.fbx",    "adduct": false},
	"slash": {"fbx": "res://assets/mixamo/slash.fbx",   "adduct": false},
	"hurt":  {"fbx": "res://assets/mixamo/hurt.fbx",    "adduct": false},
}

var _ts: Skeleton3D
var _ms: Skeleton3D
var _ap: AnimationPlayer
var _root: Node3D
var _map: Dictionary = {}
var _hips := -1
var _hips_home := Vector3.ZERO
var _animname := ""
var _adduct := true

func _initialize() -> void:
	var which := "idle"
	var uargs := OS.get_cmdline_user_args()
	if uargs.size() > 0 and ANIMS.has(uargs[0]):
		which = uargs[0]
	var fbx_path: String = ANIMS[which]["fbx"]
	_adduct = ANIMS[which]["adduct"]
	var out_path := "res://tools/rig3d/in/soph_%s_retargeted.glb" % which
	print("[export] anim=%s  fbx=%s  out=%s" % [which, fbx_path, out_path])

	# 1) carrega a Soph (alvo) -- mesh + skeleton
	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(SOPH), gs) != OK:
		push_error("[export] falha soph"); quit(1); return
	_root = gd.generate_scene(gs); get_root().add_child(_root)
	_ts = _find_skel(_root)

	# 2) carrega a anim Mixamo (driver)
	var wd := FBXDocument.new(); var ws := FBXState.new()
	if wd.append_from_file(ProjectSettings.globalize_path(fbx_path), ws) != OK:
		push_error("[export] falha fbx"); quit(1); return
	var mix := wd.generate_scene(ws); get_root().add_child(mix)
	_ms = _find_skel(mix)
	_ap = _find_ap(mix)
	if _ts == null or _ms == null or _ap == null:
		push_error("[export] faltou skel/ap"); quit(1); return
	# pega a anim com mais tracks (a principal do FBX)
	var bestn := -1
	for a in _ap.get_animation_list():
		var n := _ap.get_animation(a).get_track_count()
		if n > bestn: bestn = n; _animname = a
	var drv_len := _ap.get_animation(_animname).length
	_ap.play(_animname)

	# 3) mapa de ossos por nome (ambos viram "mixamorig_X" no engine)
	for b in _ts.get_bone_count():
		var mb := _ms.find_bone(_ts.get_bone_name(b))
		if mb < 0: mb = _ms.find_bone(_ts.get_bone_name(b).replace(":", "_"))
		if mb >= 0: _map[b] = mb
	_hips = _ts.find_bone("mixamorig_Hips")
	if _hips < 0: _hips = _ts.find_bone("mixamorig:Hips")
	if _hips >= 0: _hips_home = _ts.get_bone_pose_position(_hips)
	print("[export] ossos mapeados: %d/%d  anim=%s len=%.2fs" % [_map.size(), _ts.get_bone_count(), _animname, drv_len])

	# 4) monta a Animation amostrando o retarget quadro a quadro
	var frames := int(round(drv_len * FPS))
	frames = max(frames, 2)
	var anim := Animation.new()
	anim.length = float(frames) / FPS
	anim.loop_mode = Animation.LOOP_LINEAR
	var skel_path := String(_root.get_path_to(_ts))
	var rot_ti := {}
	for b in _map:
		var ti := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(ti, NodePath(skel_path + ":" + _ts.get_bone_name(b)))
		rot_ti[b] = ti
	var hips_ti := -1
	if _hips >= 0:
		hips_ti = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(hips_ti, NodePath(skel_path + ":" + _ts.get_bone_name(_hips)))

	for i in frames:
		var t := (float(i) / float(frames)) * drv_len
		_ap.seek(t, true)            # update=true -> aplica a pose do driver na hora
		_retarget()
		var tt := float(i) / FPS
		for b in _map:
			anim.rotation_track_insert_key(rot_ti[b], tt, _ts.get_bone_pose_rotation(b))
		if hips_ti >= 0:
			anim.position_track_insert_key(hips_ti, tt, _ts.get_bone_pose_position(_hips))
	print("[export] anim assada: %d frames, %.2fs, %d tracks" % [frames, anim.length, anim.get_track_count()])

	# 5) anexa um AnimationPlayer com a anim no root da Soph
	var lib := AnimationLibrary.new()
	lib.add_animation(which, anim)
	var ap2 := AnimationPlayer.new()
	ap2.name = "RetargetAnim"
	_root.add_child(ap2)
	ap2.owner = _root
	ap2.add_animation_library("", lib)

	# 6) tira o driver da cena (so a Soph vai pro glb) e exporta
	mix.get_parent().remove_child(mix); mix.queue_free()
	var doc := GLTFDocument.new(); var state := GLTFState.new()
	var err := doc.append_from_scene(_root, state)
	if err != OK:
		push_error("[export] append_from_scene falhou: %d" % err); quit(1); return
	err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(out_path))
	if err != OK:
		push_error("[export] write_to_filesystem falhou: %d" % err); quit(1); return
	print("[export] OK -> %s" % out_path)
	quit(0)

func _retarget() -> void:
	for b in _map:
		var mb: int = _map[b]
		var m_rest: Quaternion = _ms.get_bone_rest(mb).basis.get_rotation_quaternion()
		var m_pose: Quaternion = _ms.get_bone_pose_rotation(mb)
		var dev: Quaternion = m_rest.inverse() * m_pose
		var t_rest: Quaternion = _ts.get_bone_rest(b).basis.get_rotation_quaternion()
		_ts.set_bone_pose_rotation(b, t_rest * dev)
	if _hips >= 0:
		_ts.set_bone_pose_position(_hips, _hips_home)
	if _adduct:
		_world_rot("mixamorig_LeftArm", Vector3(0, 0, 1), -ARM_ADD)
		_world_rot("mixamorig_RightArm", Vector3(0, 0, 1), ARM_ADD)

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

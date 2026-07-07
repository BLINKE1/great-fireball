extends SceneTree
## _find_loop_pose.gd — acha o melhor ponto de LOOP de uma anim comparando a POSE
## DOS OSSOS (rotacao), nao pixels. Muito mais preciso que silhueta (o robe
## esconde as pernas). Imprime a janela [a,b] com menor "costura" de pose.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/_find_loop_pose.gd -- walk
const N := 120   # amostras densas
var _ts: Skeleton3D
var _ap: AnimationPlayer
var _len := 1.0
var _which := "walk"
var _poses: Array = []   # cada item = PackedFloat32Array de quats de todos os ossos
var _f := 0
var _ready := false

func _initialize() -> void:
	var u := OS.get_cmdline_user_args()
	if u.size() > 0: _which = u[0]
	var glb := "res://tools/rig3d/in/soph_%s_retargeted.glb" % _which
	var gd := GLTFDocument.new(); var gs := GLTFState.new()
	if gd.append_from_file(ProjectSettings.globalize_path(glb), gs) != OK:
		push_error("falha glb"); quit(1); return
	var root := gd.generate_scene(gs); get_root().add_child(root)
	_ts = _find_skel(root); _ap = _find_ap(root)
	if _ts == null or _ap == null: push_error("sem skel/ap"); quit(1); return
	var nm: String = _ap.get_animation_list()[0]
	_len = _ap.get_animation(nm).length
	_ap.play(nm)
	_ready = true

func _process(_d: float) -> bool:
	if not _ready: return false
	if _poses.size() >= N:
		_analyze(); quit(0); return true
	var t := (float(_poses.size()) / float(N)) * _len
	_ap.seek(t, true)
	var pv := PackedFloat32Array()
	for b in _ts.get_bone_count():
		var q := _ts.get_bone_pose_rotation(b)
		pv.append(q.x); pv.append(q.y); pv.append(q.z); pv.append(q.w)
	_poses.append(pv)
	return false

func _dist(i: int, j: int) -> float:
	var a: PackedFloat32Array = _poses[i]
	var b: PackedFloat32Array = _poses[j]
	var s := 0.0
	for k in a.size():
		var d: float = a[k] - b[k]
		s += d * d
	return s

func _analyze() -> void:
	# costura media entre frames consecutivos (referencia de "liso")
	var cons := 0.0
	for i in N: cons += _dist(i, (i + 1) % N)
	cons /= N
	# procura (a, L) com L = ~1 ciclo, minimizando a costura de pose
	var best_s := 1e9; var best_a := 0; var best_L := 0
	for L in range(int(N * 0.25), int(N * 0.95)):
		for a in range(0, N - L):
			var s := _dist(a, a + L)
			if s < best_s: best_s = s; best_a = a; best_L = L
	print("[loop] anim=%s  N=%d  costura_consecutiva=%.5f" % [_which, N, cons])
	print("[loop] MELHOR janela: frames [%d..%d]  L=%d  costura=%.5f  (%.2fx a consecutiva)"
		% [best_a, best_a + best_L, best_L, best_s, best_s / cons])
	print("[loop] em fracao: [%.4f, %.4f]  ciclo=%.2fs" % [float(best_a)/N, float(best_a+best_L)/N, (float(best_L)/N)*_len])

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

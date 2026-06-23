extends Node2D
## player_rig_v3.gd — PoC RIG CUTOUT + CABELO-MOLA (spring) no idle.
## Monta a Soph (base bodysuit) a partir das peças cortadas nas juntas
## (assets/rig/soph_tpose/parts/ + parts.json), poe os braços em descanso, e
## anima um IDLE com VIDA:
##   - corpo: respiração + bob + sway (seno)
##   - CABELO: mola/inércia (spring) que LAGGA o movimento do corpo -> balança
##     com peso (follow-through). É o "cabelo rigado" do runbook (versão leve,
##     1 osso pendular; multi-strand é o próximo passo).
## NÃO mexe no player.gd — nó separado, roda na nuvem (sem Blender/MediaPipe).

const PARTS_DIR  := "res://assets/rig/soph_tpose/parts/"
const PARTS_JSON := "res://assets/rig/soph_tpose/parts.json"
const RIG_SCALE  := 0.22

# --- idle (corpo) ---
const BOB_PX   := 8.0      # sobe/desce vertical
const SWAY_PX  := 7.0      # vai-e-vem horizontal
const BREATHE  := 0.025    # escala vertical do tronco
const IDLE_HZ  := 0.42     # ciclos/seg

# --- cabelo-mola ---
const HAIR_STIFF := 90.0   # rigidez (puxa de volta ao repouso)
const HAIR_DAMP  := 9.0    # amortecimento (mata oscilação)
const HAIR_LAG   := 0.016  # quanto o cabelo "trai" a velocidade do corpo
const HEAD_STIFF := 140.0  # cabeça também ganha um micro-spring (vida)
const HEAD_DAMP  := 12.0
const HEAD_LAG   := 0.006

# pose de descanso (graus): rotação dos braços saindo da T
const L_SHOULDER_DEG := 48.0
const L_ELBOW_DEG    := 25.0
const R_SHOULDER_DEG := -48.0
const R_ELBOW_DEG    := -25.0

var _root: Node2D
var _torso: Node2D
var _hair: Node2D
var _head: Node2D
var _t := 0.0
var _ok := false

# spring state
var _hair_ang := 0.0
var _hair_vel := 0.0
var _head_ang := 0.0
var _head_vel := 0.0
var _prev_sway := 0.0
var _home := Vector2.ZERO

func _ready() -> void:
	var data := _load_json(PARTS_JSON)
	if data.is_empty():
		push_error("[rig_v3] parts.json não carregou")
		return

	_root = Node2D.new()
	_root.scale = Vector2(RIG_SCALE, RIG_SCALE)
	add_child(_root)

	var parts: Dictionary = data.get("parts", {})

	# z-order explícito (independe da árvore): cabelo atrás de tudo, rosto na frente
	var zmap := {
		"hair_back": -20,
		"R_leg_upper": -2, "R_leg_lower": -2,
		"L_leg_upper": -2, "L_leg_lower": -2,
		"R_arm_upper": -1, "R_arm_lower": -1,
		"L_arm_upper": -1, "L_arm_lower": -1,
		"torso": 0,
		"head": 10,
	}

	# tronco é a raiz da árvore visível
	_torso = _make_bone("torso", parts, _root, zmap)

	# cabelo + cabeça penduram do pescoço (filhos do tronco p/ acompanhar)
	_hair = _make_bone("hair_back", parts, _torso, zmap)
	_head = _make_bone("head", parts, _torso, zmap)

	# braços: upper no ombro, lower no cotovelo (filho do upper)
	var lu := _make_bone("L_arm_upper", parts, _torso, zmap)
	var ll := _make_bone("L_arm_lower", parts, lu, zmap)
	var ru := _make_bone("R_arm_upper", parts, _torso, zmap)
	var rl := _make_bone("R_arm_lower", parts, ru, zmap)
	lu.rotation = deg_to_rad(L_SHOULDER_DEG); ll.rotation = deg_to_rad(L_ELBOW_DEG)
	ru.rotation = deg_to_rad(R_SHOULDER_DEG); rl.rotation = deg_to_rad(R_ELBOW_DEG)

	# pernas: ficam ~retas no idle (T-pose já tem perna p/ baixo)
	var lgu := _make_bone("L_leg_upper", parts, _torso, zmap)
	_make_bone("L_leg_lower", parts, lgu, zmap)
	var rgu := _make_bone("R_leg_upper", parts, _torso, zmap)
	_make_bone("R_leg_lower", parts, rgu, zmap)

	_home = _torso.position
	_ok = true

func _process(delta: float) -> void:
	if not _ok:
		return
	_t += delta
	var w := _t * TAU * IDLE_HZ
	var s := sin(w)

	# corpo: sway horizontal + bob vertical no tronco; respiração na escala Y
	var sway := SWAY_PX * sin(w + 0.6)
	_torso.position = _home + Vector2(sway, BOB_PX * 0.5 * s)
	_torso.scale.y = 1.0 - BREATHE * maxf(0.0, s)

	# velocidade horizontal do corpo (alimenta a inércia do cabelo)
	var vx := (sway - _prev_sway) / maxf(delta, 0.0001)
	_prev_sway = sway

	# cabelo: mola amortecida que persegue um alvo "atrasado" pela velocidade
	var hair_target := -HAIR_LAG * vx
	var hair_acc := HAIR_STIFF * (hair_target - _hair_ang) - HAIR_DAMP * _hair_vel
	_hair_vel += hair_acc * delta
	_hair_ang += _hair_vel * delta
	_hair.rotation = _hair_ang

	# cabeça: micro-spring (mais rígido) -> vida sutil, sem virar boneco mole
	var head_target := -HEAD_LAG * vx
	var head_acc := HEAD_STIFF * (head_target - _head_ang) - HEAD_DAMP * _head_vel
	_head_vel += head_acc * delta
	_head_ang += _head_vel * delta
	_head.rotation = _head_ang

# Cria um "osso": Node2D no pivô global da junta + Sprite2D alinhado.
func _make_bone(name: String, parts: Dictionary, parent: Node2D, zmap: Dictionary) -> Node2D:
	var p: Dictionary = parts[name]
	var tex := _load_tex(PARTS_DIR + name + ".png")
	var pivot_g := Vector2(p["pivot"][0], p["pivot"][1])
	var pivot_l := Vector2(p["pivot_local"][0], p["pivot_local"][1])

	var bone := Node2D.new()
	bone.name = name
	# posição do pivô em coords do PAI (pais também ancorados no próprio pivô)
	if parent == _torso and name != "torso":
		var tp = parts["torso"]["pivot"]
		bone.position = pivot_g - Vector2(tp[0], tp[1])
	elif parent != _root:
		# filho de outro osso (cotovelo/joelho): relativo ao pivô do pai
		var pn: String = parent.name
		var pp = parts[pn]["pivot"]
		bone.position = pivot_g - Vector2(pp[0], pp[1])
	else:
		bone.position = pivot_g
	parent.add_child(bone)

	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = -pivot_l
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.z_as_relative = false
	sp.z_index = zmap.get(name, 0)
	bone.add_child(sp)
	return bone

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := ResourceLoader.load(path)
		if t is Texture2D:
			return t
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	return null

extends Node2D
## player_rig_v2.gd — PoC de RIG CUTOUT 3/4 da Soph (idle por peças/ossos).
## NÃO mexe no player.gd: é um nó separado, experimental. Monta o boneco
## (cabeça/chapéu + corpo) a partir das peças cortadas da arte HD pintada e
## anima um IDLE procedural (respiração + bob + sway). Demonstra que rig 2D
## resolve idle/gestos no plano sem gerar frame a frame.
##
## Limites conhecidos (decisão do PoC): cast precisa do braço como peça
## separada; walk/run continuam frame-by-frame (cutout fica de fantoche).

const PARTS_DIR := "res://assets/sprites/player/rig/"
const RIG_SCALE := 0.16          # a arte HD é ~737x1536; encolhe p/ tamanho de jogo
const NECK_FRAC := 0.40          # linha do pescoço (fração da altura)

# Amplitudes do idle (em px da arte, antes do RIG_SCALE)
const BOB_PX   := 26.0
const SWAY_PX  := 14.0
const HEAD_ROT := 3.0            # graus
const BREATHE  := 0.030          # escala vertical do corpo
const IDLE_HZ  := 0.40           # ciclos por segundo

var _body_pivot: Node2D
var _head_pivot: Node2D
var _neck: Vector2
var _bottom: Vector2
var _t := 0.0
var _ok := false

func _ready() -> void:
	var head_tex := _load_tex(PARTS_DIR + "part_head.png")
	var body_tex := _load_tex(PARTS_DIR + "part_body.png")
	if head_tex == null or body_tex == null:
		push_error("[rig_v2] peças não carregaram em " + PARTS_DIR)
		return
	var w := float(body_tex.get_width())
	var h := float(body_tex.get_height())
	_neck = Vector2(w * 0.5, h * NECK_FRAC)
	_bottom = Vector2(w * 0.5, h)
	scale = Vector2(RIG_SCALE, RIG_SCALE)

	# Corpo: pivot na base (pés) p/ a respiração ancorar embaixo.
	_body_pivot = Node2D.new()
	_body_pivot.position = _bottom
	add_child(_body_pivot)
	_body_pivot.add_child(_make_sprite(body_tex, _bottom))

	# Cabeça/chapéu: pivot no pescoço p/ bob/rotação naturais.
	_head_pivot = Node2D.new()
	_head_pivot.position = _neck
	add_child(_head_pivot)
	_head_pivot.add_child(_make_sprite(head_tex, _neck))
	_ok = true

func _process(delta: float) -> void:
	if not _ok:
		return
	_t += delta
	var w := _t * TAU * IDLE_HZ
	var s := sin(w)
	var sway := SWAY_PX * sin(w + 0.6)
	_head_pivot.rotation = deg_to_rad(HEAD_ROT * s)
	_head_pivot.position = _neck + Vector2(sway, -BOB_PX * s)
	_body_pivot.position = _bottom + Vector2(sway, 0.0)
	_body_pivot.scale.y = 1.0 - BREATHE * maxf(0.0, s)

func _make_sprite(tex: Texture2D, pivot: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = -pivot          # alinha o ponto-pivot com a origem do pivot Node2D
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sp

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := ResourceLoader.load(path)
		if t is Texture2D:
			return t
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	return null

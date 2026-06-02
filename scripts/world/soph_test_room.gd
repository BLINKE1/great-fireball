extends Node2D
## Sala de testes da Soph — foco no desenvolvimento do personagem (sem historia).
##
## Overlay de debug que permite, AO VIVO:
##   - alternar HD <-> pixel-art (tecla H)
##   - ajustar escala da arte HD (tecla [ e ])
##   - ajustar offset vertical da arte HD (tecla ; e ')
##   - resetar a posicao da Soph (tecla R)
##   - ler o estado de animacao atual + velocidade
##
## Os valores de escala/offset sao aplicados direto no AnimatedSprite2D do
## player, entao da pra achar o alinhamento ideal sem reiniciar o jogo. Quando
## gostar, copie os numeros mostrados para HD_SCALE/HD_OFFSET em player.gd.

@onready var player: CharacterBody2D = $Player

var _sprite: AnimatedSprite2D
var _label: Label
var _hd: bool = true
var _scale: float = 0.34
var _offset_y: float = 0.0

const SCALE_STEP := 0.01
const OFFSET_STEP := 1.0

func _ready() -> void:
	# Endgame loadout: a sala existe pra sentir o movimento completo da Soph.
	SkillManager.unlock("double_jump")
	SkillManager.unlock("magic_dash")
	SkillManager.unlock("magic_missile")
	# player._ready ja rodou ANTES desse _ready (filho roda antes do pai), entao
	# jumps_remaining ja foi calculado com double_jump bloqueado. Recarrega.
	player.jumps_remaining = player._max_air_jumps()
	# Pega o sprite do player e o estado HD atual como ponto de partida.
	# (player.gd expoe USE_HD_SOPH/HD_SCALE/HD_OFFSET como consts.)
	_sprite = player.get_node("Sprite2D") as AnimatedSprite2D
	_hd = player.USE_HD_SOPH
	_scale = player.HD_SCALE
	_offset_y = player.HD_OFFSET.y
	_build_overlay()
	_apply()

func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	# Quase invisivel: nao polui a tela mas continua legivel se voce procurar.
	panel.modulate = Color(1, 1, 1, 0.22)
	cl.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	margin.add_child(_label)

func _process(_delta: float) -> void:
	_handle_keys()
	_update_label()

func _handle_keys() -> void:
	if Input.is_action_just_pressed("ui_test_toggle_hd"):
		_hd = not _hd
		_rebuild_frames()
	if Input.is_action_just_pressed("ui_test_scale_up"):
		_scale += SCALE_STEP; _apply()
	if Input.is_action_just_pressed("ui_test_scale_down"):
		_scale = maxf(0.05, _scale - SCALE_STEP); _apply()
	if Input.is_action_just_pressed("ui_test_offset_up"):
		_offset_y -= OFFSET_STEP; _apply()
	if Input.is_action_just_pressed("ui_test_offset_down"):
		_offset_y += OFFSET_STEP; _apply()
	if Input.is_action_just_pressed("ui_test_reset"):
		player.global_position = Vector2(200, 300)
		player.velocity = Vector2.ZERO

func _apply() -> void:
	if not _sprite:
		return
	# player._update_visuals reescreve sprite.scale todo frame como
	# _base_scale * squash. Pra que o ajuste persista, mudamos a _base_scale
	# do player (e não sprite.scale direto).
	if _hd:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		player._base_scale = Vector2(_scale, _scale)
		_sprite.position = Vector2(0, _offset_y)
	else:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player._base_scale = Vector2.ONE
		_sprite.position = Vector2.ZERO

func _rebuild_frames() -> void:
	# Reconstroi o SpriteFrames no modo escolhido, se o player expoe os helpers.
	var anim := _sprite.animation
	var frame := _sprite.frame
	if _hd and player.has_method("_build_soph_frames_hd"):
		_sprite.sprite_frames = player._build_soph_frames_hd()
	elif not _hd and player.has_method("_build_soph_frames_pixel"):
		_sprite.sprite_frames = player._build_soph_frames_pixel()
	_apply()
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_sprite.frame = frame

func _update_label() -> void:
	if not _label or not _sprite:
		return
	var spd := absf(player.velocity.x)
	_label.text = "%s  %s  vx %4.0f  scale %.2f  off %.0f\n" % [
			"HD" if _hd else "PX", _sprite.animation, spd, _scale, _offset_y] \
		+ "H mode  [ ] scale  ; ' off  R reset  Z miss  Shift dash"

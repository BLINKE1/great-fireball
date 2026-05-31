extends SceneTree
## Harness de teste headless/xvfb: carrega a sala de testes da Soph, deixa
## rodar alguns frames, tira screenshots e sai. Uso:
##   xvfb-run -a godot --rendering-driver opengl3 -s test_capture.gd
##
## Salva em user://soph_shot_*.png (mapeado p/ ~/.local/share/godot/...).

var _frames := 0
var _shots := 0
var _player: Node = null
var _room: Node = null
var _landed := false
var _land_frame := 0
var _out_dir := "res://tools/art_director/iterations/godot_shots/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	var packed := load("res://scenes/world/soph_test_room.tscn")
	if packed == null:
		push_error("FALHOU: nao carregou soph_test_room.tscn")
		quit(1)
		return
	_room = packed.instantiate()
	get_root().add_child.call_deferred(_room)
	print("HARNESS: sala agendada p/ instanciar")

func _process(_delta: float) -> bool:
	_frames += 1
	if _player == null and _room != null:
		_player = _room.get_node_or_null("Player")
		if _player:
			print("HARNESS: player encontrado")
	if _player == null:
		return false
	# Espera a Soph ATERRISSAR (ela nasce no ar) antes de capturar parada.
	if not _landed:
		if _player.is_on_floor():
			_landed = true
			_land_frame = _frames
		return false
	var t := _frames - _land_frame
	# Simula INPUT real: deixa assentar, captura parada, anda, captura, para.
	if t == 8:
		_shot("idle")                       # parada, ja no chao
		Input.action_press("ui_right")      # comeca a andar
	elif t in [20, 26, 32, 38]:
		_shot("walk_%d" % t)                # ciclo em movimento
	elif t == 52:
		Input.action_release("ui_right")    # solta -> volta a idle
	elif t >= 64:
		print("HARNESS: capturei ", _shots, " screenshots. saindo.")
		Input.action_release("ui_right")
		quit(0)
		return true
	return false

func _shot(tag: String) -> void:
	var img := get_root().get_texture().get_image()
	if img == null:
		print("HARNESS: viewport sem imagem ainda (", tag, ")")
		return
	var path := _out_dir + "soph_%s.png" % tag
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err == OK:
		_shots += 1
		print("HARNESS: shot -> ", path, "  anim=", _anim())
	else:
		print("HARNESS: erro ao salvar ", path, " err=", err)

func _anim() -> String:
	if _player == null:
		return "?"
	var spr := _player.get_node_or_null("Sprite2D")
	return spr.animation if spr else "?"

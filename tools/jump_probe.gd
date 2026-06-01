extends SceneTree
## Mede a trajetória REAL do pulo da Soph no jogo (headless).
## Dá um pulo LONGO (segura o botão) e um CURTO (solta cedo) e registra altura
## + tempo de apex, provando: pulo variável funciona e o arco está saudável.
##   xvfb-run -a $GODOT --rendering-driver opengl3 -s tools/jump_probe.gd

var _f := 0
var _player: Node = null
var _room: Node = null
var _phase := "boot"
var _start_y := 0.0
var _peak := 0.0
var _t0 := 0
var _apex_f := 0
var _results := {}

func _initialize() -> void:
	var packed := load("res://scenes/world/soph_test_room.tscn")
	_room = packed.instantiate()
	get_root().add_child.call_deferred(_room)

func _process(_d: float) -> bool:
	_f += 1
	if _player == null:
		if _room: _player = _room.get_node_or_null("Player")
		return false
	if not _player.is_on_floor() and _phase == "boot":
		return false  # espera aterrissar

	match _phase:
		"boot":
			if _player.is_on_floor():
				_phase = "long_jump"; _begin_long()
		"long_jump":
			_track()
			# segura o botão o pulo inteiro (longo)
			if _player.is_on_floor() and _f - _t0 > 5:
				_results["longo"] = {"altura": round(_start_y - _peak),
					"frames_ate_apex": _apex_f - _t0}
				_phase = "settle1"; _settle_to = _f + 20
		"settle1":
			if _f >= _settle_to and _player.is_on_floor():
				_phase = "short_jump"; _begin_short()
		"short_jump":
			_track()
			if _player.is_on_floor() and _f - _t0 > 5:
				_results["curto"] = {"altura": round(_start_y - _peak),
					"frames_ate_apex": _apex_f - _t0}
				_phase = "done"
		"done":
			_report(); quit(0); return true
	return false

var _settle_to := 0

func _begin_long() -> void:
	_start_y = _player.global_position.y; _peak = _start_y
	_t0 = _f; _apex_f = _f
	Input.action_press("ui_accept")          # segura: pulo cheio

func _begin_short() -> void:
	_start_y = _player.global_position.y; _peak = _start_y
	_t0 = _f; _apex_f = _f
	Input.action_press("ui_accept")
	# solta logo (3 frames) → pulo variável deve cortar a subida
	await_release()

func await_release() -> void:
	# solta no proximo frame util (simples: agenda via flag)
	_release_at = _f + 3

var _release_at := -1

func _track() -> void:
	if _release_at > 0 and _f >= _release_at:
		Input.action_release("ui_accept"); _release_at = -1
	var y: float = _player.global_position.y
	if y < _peak:
		_peak = y; _apex_f = _f
	# solta o botao no pulo longo perto do apex (senao fica segurado p sempre)
	if _phase == "long_jump" and _player.velocity.y > -30.0:
		Input.action_release("ui_accept")

func _report() -> void:
	print("═══ TRAJETÓRIA DO PULO (medida no jogo) ═══")
	for k in ["longo", "curto"]:
		if _results.has(k):
			var r = _results[k]
			print("  pulo %-6s → altura %4d px   apex em %d frames"
				% [k, r["altura"], r["frames_ate_apex"]])
	if _results.has("longo") and _results.has("curto"):
		var ratio := float(_results["curto"]["altura"]) / maxf(1.0, float(_results["longo"]["altura"]))
		print("  razão curto/longo: %.2f  (pulo variável %s)"
			% [ratio, "OK ✓" if ratio < 0.85 else "FRACO — quase sem diferença"])

extends SceneTree
## Valida o sistema de crítico por zona (cabeça x torso) headless.
##   $GODOT --headless -s tools/crit_probe.gd
## Posiciona um goblin, bate na cabeça (espera 2x) e no torso (espera 1x),
## conferindo o HP resultante. Também testa is_head_hit direto.

var _g: Node = null
var _f := 0
var _phase := 0
var _hp0 := 0.0

func _initialize() -> void:
	var packed := load("res://scenes/enemies/goblin.tscn")
	_g = packed.instantiate()
	_g.position = Vector2(200, 200)   # longe da origem (evita falso-positivo)
	get_root().add_child.call_deferred(_g)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 12:
		return false   # deixa _ready + física registrarem as Area2D
	if _g == null or not is_instance_valid(_g):
		print("⚠ goblin sumiu"); quit(1); return true

	var head: Vector2 = _g.global_position + Vector2(0, -13)
	var body: Vector2 = _g.global_position + Vector2(0, 10)

	match _phase:
		0:
			var h: bool = HitZones.is_head_hit(_g, head)
			var b: bool = HitZones.is_head_hit(_g, body)
			print("is_head_hit cabeça=%s torso=%s" % [h, b])
			if not h or b:
				print("FALHA: zonas não resolvem (cabeça deve ser true, torso false)")
				quit(1); return true
			_hp0 = _g.hp
			_phase = 1
		1:
			# Golpe no torso: dano normal (10 → hp cai 10)
			_g.take_damage(10.0, body)
			var d_body: float = _hp0 - _g.hp
			print("torso: dano aplicado = %.0f (esperado 10)" % d_body)
			if abs(d_body - 10.0) > 0.01:
				print("FALHA torso"); quit(1); return true
			_hp0 = _g.hp
			_phase = 2
		2:
			# Golpe na cabeça: crítico (10 → hp cai 20)
			_g.take_damage(10.0, head)
			var d_head: float = _hp0 - _g.hp
			print("cabeça: dano aplicado = %.0f (esperado 20 = crítico 2x)" % d_head)
			if abs(d_head - 20.0) > 0.01:
				print("FALHA cabeça"); quit(1); return true
			print("RESULTADO: crítico por zona OK ✓ (torso 1x, cabeça 2x)")
			quit(0); return true
	return false

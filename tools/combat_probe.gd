extends SceneTree
## Smoke test do caminho de dano "delicioso" do goblin (headless).
## Dispara um golpe não-letal e depois o letal; confirma que roda sem crash e
## que o goblin morre/libera.
##   $GODOT --headless -s tools/combat_probe.gd

var _goblin: Node = null
var _f := 0
var _phase := 0

func _initialize() -> void:
	var packed := load("res://scenes/enemies/goblin.tscn")
	_goblin = packed.instantiate()
	get_root().add_child.call_deferred(_goblin)

func _process(_d: float) -> bool:
	_f += 1
	if _goblin == null or not is_instance_valid(_goblin):
		if _phase >= 2:
			print("✓ goblin liberado após golpe letal")
			print("RESULTADO: caminho de combate roda sem crash ✓")
			quit(0); return true
		print("⚠ goblin sumiu cedo demais"); quit(1); return true
	if _f < 3:
		return false   # deixa o _ready assentar
	match _phase:
		0:
			print("hp inicial: %.0f" % _goblin.hp)
			_goblin.take_damage(20.0, Vector2(-50, 0))   # não-letal
			print("após golpe 20: hp %.0f, is_dead=%s" % [_goblin.hp, _goblin.is_dead])
			_phase = 1
		1:
			_goblin.take_damage(50.0, Vector2(-50, 0))    # letal (MAX_HP=40)
			print("após golpe 50: hp %.0f, is_dead=%s" % [_goblin.hp, _goblin.is_dead])
			_phase = 2
		2:
			pass  # aguarda o queue_free do _die
	return false

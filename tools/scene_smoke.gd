extends SceneTree
## Smoke test: instancia cada cena de gameplay, deixa rodar 2 frames e libera.
## Pega erros de _ready (nó faltando, path errado, null) que o import não vê.
## Um stub player em "player" satisfaz inimigos que buscam o player no _ready.
##   $GODOT --headless -s tools/scene_smoke.gd

var _scenes := [
	"res://scenes/effects/damage_number.tscn",
	"res://scenes/enemies/fire_goblin_archer.tscn",
	"res://scenes/enemies/fire_goblin_arrow.tscn",
	"res://scenes/enemies/forest_ogre.tscn",
	"res://scenes/enemies/goblin.tscn",
	"res://scenes/enemies/goblin_archer.tscn",
	"res://scenes/enemies/goblin_arrow.tscn",
	"res://scenes/enemies/goblin_leader.tscn",
	"res://scenes/enemies/goblin_mutant.tscn",
	"res://scenes/enemies/golem.tscn",
	"res://scenes/enemies/ogre_shockwave.tscn",
	"res://scenes/player/sword_slash.tscn",
	"res://scenes/spells/magic_missile.tscn",
	"res://scenes/spells/missile_curved.tscn",
	"res://scenes/spells/missile_giant.tscn",
	"res://scenes/spells/missile_piercing.tscn",
	"res://scenes/spells/missile_spread.tscn",
	"res://scenes/world/checkpoint.tscn",
	"res://scenes/world/mana_orb.tscn",
]

var _i := -1
var _f := 0
var _cur: Node = null
var _ok := 0

class StubPlayer extends Node2D:
	func take_damage(_a: float, _b: Vector2 = Vector2.ZERO) -> void: pass
	func shake(_a: float, _b: float) -> void: pass

func _initialize() -> void:
	var stub := StubPlayer.new()
	stub.add_to_group("player")
	get_root().add_child.call_deferred(stub)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 3:
		return false
	# Libera a cena anterior e avança.
	if _cur and is_instance_valid(_cur):
		_cur.queue_free()
	_i += 1
	if _i >= _scenes.size():
		print("SMOKE: %d/%d cenas instanciaram sem erro de carga ✓" % [_ok, _scenes.size()])
		quit(0); return true
	var path: String = _scenes[_i]
	var packed = load(path)
	if packed == null:
		print("✗ FALHOU load: ", path)
	else:
		_cur = packed.instantiate()
		get_root().add_child(_cur)
		_ok += 1
		print("ok: ", path)
	_f = 0
	return false

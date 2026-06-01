extends Node

signal mana_changed(ratio: float)
signal mana_depleted

@export var max_mana: float = 100.0
@export var regen_rate: float = 0.0          # mana/sec — só liga FORA de combate
@export var out_of_combat_delay: float = 2.0  # seg. sem gastar/levar dano p/ regen ligar

var current_mana: float
var _lull_timer: float = 0.0   # tempo restante até a regen poder ligar

func _ready() -> void:
	current_mana = max_mana

func _process(delta: float) -> void:
	if _lull_timer > 0.0:
		_lull_timer -= delta
	# Regen passivo (híbrido): só fora de combate, e devagar.
	if regen_rate > 0.0 and current_mana < max_mana and _lull_timer <= 0.0:
		_set_mana(current_mana + regen_rate * delta)

func spend(amount: float) -> bool:
	if current_mana < amount:
		mana_depleted.emit()
		return false
	_lull_timer = out_of_combat_delay   # gastar mana pausa a regen passiva
	_set_mana(current_mana - amount)
	return true

func bump_combat() -> void:
	# Chamado ao levar dano: mantém a regen passiva pausada durante a luta.
	_lull_timer = out_of_combat_delay

func restore(amount: float) -> void:
	_set_mana(current_mana + amount)

func restore_full() -> void:
	_set_mana(max_mana)

func get_ratio() -> float:
	return current_mana / max_mana

func _set_mana(value: float) -> void:
	current_mana = clamp(value, 0.0, max_mana)
	mana_changed.emit(current_mana / max_mana)

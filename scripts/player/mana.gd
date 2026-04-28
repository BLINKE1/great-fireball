extends Node

signal mana_changed(ratio: float)

@export var max_mana: float = 100.0
@export var regen_rate: float = 0.0  # mana/sec, increased by equipment

var current_mana: float

func _ready() -> void:
	current_mana = max_mana

func _process(delta: float) -> void:
	if regen_rate > 0.0 and current_mana < max_mana:
		_set_mana(current_mana + regen_rate * delta)

func spend(amount: float) -> bool:
	if current_mana < amount:
		return false
	_set_mana(current_mana - amount)
	return true

func restore(amount: float) -> void:
	_set_mana(current_mana + amount)

func restore_full() -> void:
	_set_mana(max_mana)

func get_ratio() -> float:
	return current_mana / max_mana

func _set_mana(value: float) -> void:
	current_mana = clamp(value, 0.0, max_mana)
	mana_changed.emit(current_mana / max_mana)

extends Node

signal hp_changed(ratio: float)
signal died

@export var max_hp: float = 100.0

var current_hp: float

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	_set_hp(current_hp - amount)
	if current_hp <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_set_hp(current_hp + amount)

func restore_full() -> void:
	_set_hp(max_hp)

func get_ratio() -> float:
	return current_hp / max_hp

func _set_hp(value: float) -> void:
	current_hp = clamp(value, 0.0, max_hp)
	hp_changed.emit(current_hp / max_hp)

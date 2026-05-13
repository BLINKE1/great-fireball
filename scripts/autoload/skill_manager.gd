extends Node

signal skill_unlocked(skill_name: String)

const DISPLAY_NAMES = {
	"time_stop":     "Parar o Tempo",
	"heal":          "Cura",
	"magic_missile": "Míssil Mágico",
	"magic_dash":    "Dash Mágico",
	"sword":         "Golpe de Cajado",
	"double_jump":   "Duplo Salto",
}

const KEYS = {
	"time_stop":     "X",
	"heal":          "C",
	"magic_missile": "Z",
	"magic_dash":    "Shift",
	"sword":         "Q",
	"double_jump":   "(auto)",
}

var _unlocked: Dictionary = {
	"sword":         true,
	"time_stop":     false,
	"heal":          false,
	"magic_missile": false,
	"magic_dash":    false,
	"double_jump":   false,
}

func reset() -> void:
	for key in _unlocked.keys():
		_unlocked[key] = false
	_unlocked["sword"] = true

func unlock(skill: String) -> void:
	if _unlocked.get(skill, false):
		return
	_unlocked[skill] = true
	skill_unlocked.emit(skill)

func has(skill: String) -> bool:
	return _unlocked.get(skill, false)

func display_name(skill: String) -> String:
	return DISPLAY_NAMES.get(skill, skill)

func key_for(skill: String) -> String:
	return KEYS.get(skill, "?")

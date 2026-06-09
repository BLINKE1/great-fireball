extends Node

signal skill_unlocked(skill_name: String)

const DISPLAY_NAMES = {
	"time_stop":          "Parar o Tempo",
	"heal":               "Cura",
	"magic_missile":      "Míssil Mágico",
	"missile_spread":     "Míssil Duplo",
	"missile_piercing":   "Míssil Perfurante",
	"missile_giant":      "Míssil Gigante",
	"missile_curved":     "Míssil Curvo",
	"magic_shield":       "Escudo Mágico",
	"magic_dash":         "Dash Mágico",
	"sword":              "Golpe de Cajado",
	"double_jump":        "Duplo Salto",
	"convoke":            "Convocar Juju",
	"convoke_will":       "Convocar Will",
}

const KEYS = {
	"time_stop":          "X",
	"heal":               "C",
	"magic_missile":      "Z",
	"missile_spread":     "A",
	"missile_piercing":   "S",
	"missile_giant":      "D",
	"missile_curved":     "E",
	"magic_shield":       "F",
	"magic_dash":         "Shift",
	"sword":              "Q",
	"double_jump":        "(auto)",
	"convoke":            "V",
	"convoke_will":       "B",
}

const DESCRIPTIONS = {
	"magic_missile":    "Dispara um míssil mágico de energia.",
	"missile_spread":   "Dispara dois mísseis em leque simultâneos.",
	"missile_piercing": "Um míssil que atravessa inimigos sem parar.",
	"missile_giant":    "Concentra toda a mana num míssil devastador.",
	"missile_curved":   "Um míssil em arco que transpõe barreiras pelo alto.",
	"time_stop":        "Paralisa todos os inimigos por instantes.",
	"heal":             "Recupera pontos de vida com magia.",
	"magic_dash":       "Rasga o espaço com um traço mágico.",
	"sword":            "Golpeia diretamente com o cajado.",
	"double_jump":      "Salta uma segunda vez no ar.",
	"magic_shield":     "Cria um escudo que absorve todo dano por alguns segundos.",
	"convoke":          "Convoca a Juju, que adormece todos os inimigos por 10s.",
	"convoke_will":     "Convoca o Will, que cai do céu e defende com um escudo gigante por 10s.",
}

var _unlocked: Dictionary = {
	"sword":            true,
	"time_stop":        false,
	"heal":             false,
	"magic_missile":    false,
	"missile_spread":   false,
	"missile_piercing": false,
	"missile_giant":    false,
	"missile_curved":   false,
	"magic_dash":       false,
	"double_jump":      false,
	"magic_shield":     false,
	"convoke":          false,
	"convoke_will":     false,
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

func description(skill: String) -> String:
	return DESCRIPTIONS.get(skill, "")

extends CanvasLayer

signal dialogue_finished

const CHAR_DELAY = 0.036

@onready var name_badge: ColorRect = $Background/Margin/VBox/NameBadge
@onready var name_label: Label     = $Background/Margin/VBox/NameBadge/NameLabel
@onready var text_label: Label     = $Background/Margin/VBox/TextLabel
@onready var hint_label: Label     = $Background/Margin/VBox/HintLabel

# Speaker name → accent color for the top border
const SPEAKER_COLORS = {
	"Mago Graduado": Color(1.00, 0.55, 0.10),
	"Soph":          Color(0.28, 0.58, 1.00),
	"Maga":          Color(0.28, 0.58, 1.00),
	"Dica":          Color(0.30, 0.90, 0.45),
}

var _lines: Array = []
var _names: Array = []
var _current: int = 0
var _typing: bool = false
var _char_timer: float = 0.0
var _char_index: int = 0
var _full_text: String = ""

func show_dialogue(lines: Array, names: Array = []) -> void:
	_lines = lines
	_names = names
	_current = 0
	visible = true
	_show_current()

func _show_current() -> void:
	if _current >= _lines.size():
		visible = false
		dialogue_finished.emit()
		return

	_full_text = _lines[_current]
	var speaker = _names[_current] if _current < _names.size() else ""
	name_label.text = speaker
	name_badge.visible = speaker != ""

	# Accent color based on speaker
	if speaker != "":
		var col: Color = SPEAKER_COLORS.get(speaker, Color(0.28, 0.55, 1.0))
		name_badge.color = Color(col.r * 0.30, col.g * 0.30, col.b * 0.30, 0.88)
		name_label.add_theme_color_override("font_color", col.lightened(0.25))
		$Background/TopBorder.color = Color(col.r, col.g, col.b, 0.88)
	else:
		$Background/TopBorder.color = Color(0.22, 0.44, 0.80, 0.85)

	text_label.text = ""
	hint_label.visible = false
	_char_index = 0
	_char_timer = 0.0
	_typing = true

func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_char_timer -= delta
	if _char_timer <= 0.0:
		_char_timer = CHAR_DELAY
		if _char_index < _full_text.length():
			text_label.text = _full_text.substr(0, _char_index + 1)
			_char_index += 1
			if _char_index % 2 == 0:
				AudioManager.play("tick", randf_range(0.88, 1.15))
		else:
			_typing = false
			hint_label.visible = true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _typing:
			text_label.text = _full_text
			_char_index = _full_text.length()
			_typing = false
			hint_label.visible = true
		else:
			_current += 1
			_show_current()
		get_viewport().set_input_as_handled()

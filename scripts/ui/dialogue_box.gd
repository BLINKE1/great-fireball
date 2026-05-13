extends CanvasLayer

signal dialogue_finished

const CHAR_DELAY = 0.038

@onready var name_label: Label = $Background/Margin/VBox/NameLabel
@onready var text_label: Label = $Background/Margin/VBox/TextLabel
@onready var hint_label: Label = $Background/Margin/VBox/HintLabel

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
	name_label.visible = speaker != ""
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

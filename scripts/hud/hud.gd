extends CanvasLayer

@onready var hp_bar: ProgressBar = $Margin/VBox/HPBar
@onready var mana_bar: ProgressBar = $Margin/VBox/ManaBar
@onready var time_stop_overlay: ColorRect = $TimeStopOverlay

func _ready() -> void:
	GameState.time_stop_started.connect(func(): time_stop_overlay.visible = true)
	GameState.time_stop_ended.connect(func(): time_stop_overlay.visible = false)
	call_deferred("_connect_to_player")

func _connect_to_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.hp.hp_changed.connect(_on_hp_changed)
	player.mana.mana_changed.connect(_on_mana_changed)
	_on_hp_changed(player.hp.get_ratio())
	_on_mana_changed(player.mana.get_ratio())

func _on_hp_changed(ratio: float) -> void:
	hp_bar.value = ratio * 100.0

func _on_mana_changed(ratio: float) -> void:
	mana_bar.value = ratio * 100.0

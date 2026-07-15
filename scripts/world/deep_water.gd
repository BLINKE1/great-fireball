extends Area2D

# Zona de agua FUNDA (tema alagados): enquanto a Soph esta' dentro, ela vadeia
# mais devagar (arrasto). Splash + gotas ao ENTRAR e SAIR. A leitura de "fundo"
# vem do arrasto + splash + os passos que ja' soltam ondas ali. Ignora tudo que
# nao for o player (o chao tambem entra no Area2D).

@export var slow_mult: float = 0.55

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if "water_speed_mult" in body:
		body.water_speed_mult = slow_mult
	_splash(body)

func _on_exit(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if "water_speed_mult" in body:
		body.water_speed_mult = 1.0
	_splash(body)

func _splash(body: Node2D) -> void:
	AudioManager.play("splash")
	var scene := get_tree().current_scene
	if scene != null:
		VFX.burst(body.global_position + Vector2(0.0, 22.0), scene,
				Color(0.72, 0.90, 1.0, 0.85), 14, 96.0, 300.0)

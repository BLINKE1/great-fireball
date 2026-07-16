extends Area2D
## Sala metroidvania (room-lock de camera). Ao a Soph entrar, trava os limites
## da Camera2D dela neste retangulo — a camera DESLIZA suave pro novo
## enquadramento (position smoothing ja' vem ligado na camera do player). Salas
## adjacentes sao Area2Ds vizinhas; ao cruzar a porta, a proxima sala remira a
## camera. Arquitetura pronta pra virar area exploravel (basta encostar salas).
##
## Uso: Area2D com este script + um CollisionShape2D RectangleShape2D cobrindo a
## sala. Grupo "tower_room". Opcional: `entry_tag` p/ spawns nomeados no futuro.

@export var lock_y: bool = true       # false = trava so' X (sala de altura livre)
@export var entry_tag: String = ""    # ancora de spawn (expansao futura)

func _ready() -> void:
	add_to_group("tower_room")
	monitoring = true
	body_entered.connect(_on_body_entered)

func room_rect() -> Rect2:
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var sz: Vector2 = (c.shape as RectangleShape2D).size
			var center: Vector2 = global_position + c.position
			return Rect2(center - sz * 0.5, sz)
	return Rect2()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var cam := body.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var r := room_rect()
	if r.size == Vector2.ZERO:
		return
	cam.limit_left = int(r.position.x)
	cam.limit_right = int(r.position.x + r.size.x)
	if lock_y:
		cam.limit_top = int(r.position.y)
		cam.limit_bottom = int(r.position.y + r.size.y)

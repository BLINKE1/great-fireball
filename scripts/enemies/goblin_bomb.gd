extends Area2D
## Bomba do Goblin Mutante (kit Siege-Gang): voa em ARCO, quica no chao, pisca
## acelerando e EXPLODE em area. HK-fair: o blink e' o telegraph — da' tempo de
## sair. E e' REBATIVEL: o slash a devolve pro boss (grupo enemy_projectile +
## parry()) — bomba rebatida explode nos INIMIGOS com dano dobrado.

const GRAVITY   = 620.0
const DAMAGE    = 24.0
const RADIUS    = 62.0        # raio da explosao
const FUSE      = 1.15        # tempo no chao ate explodir
const LIFETIME  = 6.0

var vx: float = 120.0         # setado pelo boss (arco variavel)
var vy: float = -300.0
var land_y: float = 1e9      # linha do chao (setada pelo boss)
var _grounded := false
var _fuse := FUSE
var _blink := 0.0
var _parried := false
var _exploded := false

func _ready() -> void:
	var tex := SpriteSetup.get_texture("goblin_bomb")
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		$Sprite2D.modulate = Color(0.16, 0.16, 0.18)   # esfera escura placeholder
	add_to_group("enemy_projectile")
	get_tree().create_timer(LIFETIME).timeout.connect(_explode)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if GameState.time_stopped or _exploded: return
	if not _grounded:
		vy += GRAVITY * delta
		position.x += vx * delta
		position.y += vy * delta
		$Sprite2D.rotation += vx * 0.02 * delta * 60.0
		if position.y >= land_y and vy > 0.0:
			position.y = land_y
			if absf(vy) > 140.0 and not _parried:
				vy = -vy * 0.38; vx *= 0.6   # quique curto
				AudioManager.play("stomp", 1.6)
			else:
				_grounded = true
				vx = 0.0
	else:
		# pavio: pisca acelerando (o telegraph da explosao)
		_fuse -= delta
		_blink -= delta
		if _blink <= 0.0:
			_blink = maxf(0.06, _fuse * 0.22)
			$Sprite2D.modulate = Color(2.2, 0.5, 0.4) if $Sprite2D.modulate.r < 2.0 \
					else (Color.WHITE if SpriteSetup.get_texture("goblin_bomb") else Color(0.16, 0.16, 0.18))
			AudioManager.play("detect", 1.8)
		if _fuse <= 0.0:
			_explode()

func _on_body_entered(body: Node) -> void:
	# rebatida: explode no que tocar (inimigos); normal: só arma no chao
	if _parried and body.is_in_group("enemy"):
		_explode()

## Rebatida pelo slash: volta na direcao contraria, mais rapida, e agora fere
## INIMIGOS (dano dobrado). O clang/hitstop vem do sword_slash.
func parry(from: Vector2 = Vector2.ZERO) -> void:
	if _parried or _exploded: return
	_parried = true
	_grounded = false
	var dir := signf(global_position.x - from.x)
	if dir == 0.0: dir = 1.0
	vx = dir * 320.0
	vy = -180.0
	$Sprite2D.modulate = Color(0.5, 1.6, 2.2)   # azul-mana: agora e' NOSSA
	VFX.ring(global_position, get_parent(), Color(0.4, 0.9, 1.0, 0.9), 26.0, 0.25)

func _explode() -> void:
	if _exploded: return
	_exploded = true
	var p := get_parent()
	var pos := global_position
	AudioManager.play("stomp", 0.55)
	VFX.burst(pos, p, Color(1.0, 0.55, 0.15), 30, 210.0, -30.0)
	VFX.burst(pos, p, Color(0.9, 0.2, 0.08), 18, 140.0, -10.0)
	VFX.ring(pos, p, Color(1.0, 0.7, 0.25, 0.95), RADIUS, 0.4)
	VFX.ground_burst(Vector2(pos.x, pos.y + 6), p, Color(0.45, 0.35, 0.20), 14)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and is_instance_valid(pl) and pl.has_method("shake"):
		pl.shake(6.0, 0.25)
	if _parried:
		# nossa bomba: fere inimigos no raio (dano dobrado — recompensa do parry)
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.has_method("take_damage") \
					and e.global_position.distance_to(pos) <= RADIUS * 1.25:
				e.take_damage(DAMAGE * 2.0, pos)
	else:
		if pl and is_instance_valid(pl) and pl.has_method("take_damage") \
				and pl.global_position.distance_to(pos) <= RADIUS:
			pl.take_damage(DAMAGE, pos)
	queue_free()

extends Node2D
## Facho de energia do Goblin Mutante — raio contínuo de ENERGY_DURATION segundos
## disparado pelo braço mutante. É o ÚNICO ataque que dana o HP do escudo do Will.
## Um facho sozinho não estoura; ~3 somados sim. Enquanto o escudo aguenta, o raio
## para nele; quando o escudo estoura, o raio "vara" e alcança a Soph.

const DURATION   := 3.0
const MAX_LEN    := 560.0
const SHIELD_DPS := 32.0     # dano/seg ao HP do escudo (3 fachos juntos ~> 200 HP)
const PLAYER_DMG := 22.0     # dano à Soph quando o raio a alcança (limitado por i-frame)
const Y_TOL      := 64.0     # tolerância vertical pra considerar "na linha do raio"

var direction: float = 1.0
var shooter: Node = null      # o boss (pra seguir o braço); pode morrer no meio

var _origin: Vector2
var _t := 0.0
var _core: Line2D
var _glow: Line2D
var _player: Node = null
var _muzzle := 0.0

func _ready() -> void:
	add_to_group("boss_beam")
	_origin = global_position
	_player = get_tree().get_first_node_in_group("player")
	_glow = Line2D.new()
	_glow.width = 22.0
	_glow.default_color = Color(0.55, 0.20, 0.85, 0.30)   # halo púrpura (mutação)
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_glow)
	_core = Line2D.new()
	_core.width = 8.0
	_core.default_color = Color(0.75, 1.0, 0.55, 0.95)    # núcleo verde-energia
	_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_core)
	AudioManager.play("missile_giant", 0.55)

func _physics_process(delta: float) -> void:
	if GameState.time_stopped:
		return
	_t += delta
	if _t >= DURATION:
		_fade_out()
		return

	# Origem segue o braço do boss (se ainda vivo).
	if shooter and is_instance_valid(shooter) and not shooter.is_dead:
		_origin = shooter.global_position + Vector2(direction * 56.0, -10.0)
	global_position = _origin

	# Comprimento efetivo: para no escudo do Will mais próximo que ainda aguenta.
	var end_len := MAX_LEN
	var blocking: Node = null
	for s in get_tree().get_nodes_in_group("will_shield"):
		if not is_instance_valid(s): continue
		if not (s.has_method("is_guarding") and s.is_guarding()): continue
		var rel: Vector2 = s.global_position - _origin
		if signf(rel.x) != direction: continue
		if absf(rel.y) > Y_TOL: continue
		var d := absf(rel.x)
		if d <= end_len:
			end_len = d
			blocking = s
	if blocking:
		blocking.damage_shield(SHIELD_DPS * delta, _origin)

	# Alcança a Soph? (só se ela estiver DENTRO do comprimento efetivo — atrás de um
	# escudo intacto, end_len < distância dela → não acerta. Escudo estoura → acerta.)
	if _player and is_instance_valid(_player) and _player.has_method("take_damage"):
		var pr: Vector2 = _player.global_position - _origin
		if signf(pr.x) == direction and absf(pr.y) < Y_TOL and absf(pr.x) <= end_len:
			_player.take_damage(PLAYER_DMG, _origin)

	# Visual.
	var tip := Vector2(direction * end_len, 0.0)
	var pulse := 1.0 + 0.18 * sin(_t * 40.0)
	var ramp := clampf(_t / 0.15, 0.0, 1.0)
	_core.points = PackedVector2Array([Vector2.ZERO, tip])
	_glow.points = PackedVector2Array([Vector2.ZERO, tip])
	_core.width = 8.0 * pulse * ramp
	_glow.width = 22.0 * pulse * ramp
	# Fagulhas na origem + impacto na ponta.
	_muzzle -= delta
	if _muzzle <= 0.0:
		_muzzle = 0.04
		VFX.sparkle(_origin, get_parent(), Color(0.8, 1.0, 0.6), 2)
		var tip_world := _origin + tip
		VFX.burst(tip_world, get_parent(), Color(0.7, 1.0, 0.5), 3,
				60.0 if blocking else 40.0, 12.0)
		if blocking:
			VFX.ring(tip_world, get_parent(), Color(0.6, 0.9, 1.0, 0.6), 16.0, 0.18)

func _fade_out() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(_core, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(_glow, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)

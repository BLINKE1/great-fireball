extends Node2D
## Will — o aliado DEFENSIVO do Convoke.
## Cai do céu com um escudo gigante, ESMAGA (overkill) quem estiver no ponto de
## queda, e fica em GUARDA por GUARD_TIME segundos antes de pular pra fora da tela.
##
## O escudo não é invulnerável: tem HP. Hits de mobs e do boss (melee/flecha/
## shockwave) são 100% absorvidos (aguenta todos). SÓ o facho do Goblin Mutante
## dana o HP do escudo — 1 não estoura, ~3 somados sim. Estourando, ele recua e o
## facho passa a varar até a Soph.

const SHIELD_MAX     := 200.0
const GUARD_TIME     := 10.0
const FALL_TIME      := 0.34
const FALL_HEIGHT    := 340.0
const SMASH_RADIUS   := 64.0
const SMASH_BOSS_DMG := 60.0    # no boss é um trancão, não overkill

# Tamanho do cavaleiro GIGANTE (quase a altura do Goblin Mutante ~112px), com
# ênfase vertical. Centralizado aqui pra body/escudo ficarem alinhados.
const BODY_SCALE   := Vector2(3.0, 3.6)
const BODY_Y       := -50.0
const SHIELD_SCALE := Vector2(2.7, 3.7)
const SHIELD_X     := 38.0
const SHIELD_Y     := -52.0

enum St { FALL, GUARD, LEAVE }

var facing: float = 1.0
var shield_hp: float = SHIELD_MAX

var _state: int = St.FALL
var _guard_t := 0.0
var _broken := false
var _rig: Node2D
var _body: Sprite2D
var _shield: Sprite2D

func _ready() -> void:
	add_to_group("will_shield")
	_rig = Node2D.new()
	add_child(_rig)
	_body = Sprite2D.new()
	_body.texture = SpriteSetup.get_texture("will")
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.scale = BODY_SCALE
	_body.position = Vector2(0, BODY_Y)
	_body.flip_h = facing < 0
	_rig.add_child(_body)
	_shield = Sprite2D.new()
	_shield.texture = SpriteSetup.get_texture("will_shield")
	_shield.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shield.scale = SHIELD_SCALE
	_shield.position = Vector2(facing * SHIELD_X, SHIELD_Y)
	_rig.add_child(_shield)
	# Começa lá no alto e despenca.
	_rig.position = Vector2(0, -FALL_HEIGHT)
	var tw := create_tween()
	tw.tween_property(_rig, "position", Vector2.ZERO, FALL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_land)
	# Telegrafa a sombra da queda no chão.
	VFX.ring(global_position + Vector2(0, 6), get_parent(), Color(0.2, 0.2, 0.3, 0.5), SMASH_RADIUS, FALL_TIME)
	AudioManager.play("roar", 1.1)

func _land() -> void:
	_state = St.GUARD
	_guard_t = GUARD_TIME
	AudioManager.play("stomp", 0.8)
	# Impacto: poeira, anel, tremor.
	VFX.ground_burst(global_position + Vector2(0, 4), get_parent(), Color(0.55, 0.45, 0.28), 26)
	VFX.ring(global_position, get_parent(), Color(0.85, 0.75, 0.4, 0.85), 80.0, 0.45)
	VFX.burst(global_position + Vector2(0, -10), get_parent(), Color(0.7, 0.75, 0.85), 16, 130.0, 50.0)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and is_instance_valid(pl) and pl.has_method("shake"):
		pl.shake(16.0, 0.5)
	# Squash de aterrissagem.
	_rig.scale = Vector2(1.25, 0.72)
	create_tween().tween_property(_rig, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_smash()

func _smash() -> void:
	# ESMAGA quem estiver no ponto de queda: mobs morrem (overkill), boss leva trancão.
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) > SMASH_RADIUS:
			continue
		if not e.has_method("take_damage"):
			continue
		if e.is_in_group("boss"):
			e.take_damage(SMASH_BOSS_DMG, global_position)
		else:
			VFX.burst(e.global_position, get_parent(), Color(1.0, 0.95, 0.6), 22, 150.0, 40.0)
			e.take_damage(99999.0, global_position)

func _physics_process(delta: float) -> void:
	if _state != St.GUARD:
		return
	_guard_t -= delta
	# Pequena respiração de guarda + brilho do emblema.
	_shield.position.y = SHIELD_Y + sin(_guard_t * 4.0) * 0.6
	if _guard_t <= 0.0:
		_leave(false)

func is_guarding() -> bool:
	return _state == St.GUARD and not _broken and shield_hp > 0.0

# Hit comum de mob/boss (melee/flecha/shockwave): 100% absorvido, não custa HP.
func block_hit(_amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if not is_guarding():
		return
	AudioManager.play("shield_hit", randf_range(0.9, 1.1))
	var kick := signf(from.x - global_position.x)
	if kick == 0.0: kick = -facing
	var tw := create_tween()
	tw.tween_property(_shield, "position:x", facing * SHIELD_X - kick * 4.0, 0.05)
	tw.tween_property(_shield, "position:x", facing * SHIELD_X, 0.12)
	VFX.hit_spark(_shield.global_position, get_parent(), -kick)

# Dano de verdade ao escudo (SÓ o facho do boss chama isto).
func damage_shield(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if not is_guarding():
		return
	shield_hp -= amount
	var ratio := clampf(shield_hp / SHIELD_MAX, 0.0, 1.0)
	# Aço esquenta pro vermelho conforme racha.
	_shield.modulate = Color(1.0, 0.45 + 0.55 * ratio, 0.35 + 0.65 * ratio)
	if shield_hp <= 0.0:
		_break(from)

func _break(from: Vector2) -> void:
	_broken = true
	AudioManager.play("shield_break", 1.0)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and is_instance_valid(pl) and pl.has_method("shake"):
		pl.shake(12.0, 0.4)
	# Estilhaços do escudo.
	VFX.burst(_shield.global_position, get_parent(), Color(0.7, 0.75, 0.85), 26, 180.0, 60.0)
	VFX.burst(_shield.global_position, get_parent(), Color(0.9, 0.8, 0.4), 14, 130.0, 40.0)
	VFX.ring(_shield.global_position, get_parent(), Color(1.0, 0.85, 0.4, 0.8), 50.0, 0.4)
	var tw := _shield.create_tween()
	tw.tween_property(_shield, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(_shield, "scale", SHIELD_SCALE * 1.2, 0.25)
	tw.parallel().tween_property(_shield, "rotation", randf_range(-0.6, 0.6), 0.25)
	# Sem escudo, ele não tem o que fazer: recua e sai.
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		_leave(true)

func _leave(broke: bool) -> void:
	if _state == St.LEAVE:
		return
	_state = St.LEAVE
	if not broke:
		AudioManager.play("dash", 1.05)
		VFX.sparkle(global_position + Vector2(0, -20), get_parent(), Color(0.8, 0.85, 1.0), 12)
	# Pula pra fora da tela (pra cima) e some.
	var tw := create_tween()
	tw.tween_property(_rig, "position", Vector2(facing * 40.0, -2.0), 0.12).set_ease(Tween.EASE_OUT)   # agacha
	tw.tween_property(_rig, "position", Vector2(facing * 120.0, -460.0), 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.55)
	tw.tween_callback(queue_free)

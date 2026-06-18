extends CharacterBody2D
## GOBLIN MUTANTE — boss do vertical slice (~2x a Soph).
## Inspiração: Goblin Mutant / Siege-Gang Commander (MTG). Brutamonte que esmaga,
## investe, invoca capangas e arremessa à distância — em 3 fases que escalam a
## agressão. Telegrafa TODOS os golpes (justo), mas tem super-armadura: apanhar
## NÃO interrompe o ataque dele — você esquiva, não trava.
##
## Tato: as constantes no topo são feitas pra ajuste no playtest. Comecei num
## "difícil-mas-justo"; sem medo de afinar.

enum Phase { ONE, TWO, THREE }
enum St { IDLE, WINDUP, ACTIVE, RECOVER }

# ── Vida / movimento ──
const MAX_HP          = 280.0
const GRAVITY         = 980.0
const KNOCKBACK_DECAY = 480.0     # pesado: difícil de empurrar
const WALK_SPEED      = 46.0
const DETECT_RANGE    = 650.0

# ── Alcances de decisão ──
const SWIPE_RANGE  = 96.0     # tapa do braço gigante
const SLAM_RANGE   = 132.0    # pisão AoE
const CHARGE_NEAR  = 150.0    # investe quando está nesta faixa…
const CHARGE_FAR   = 500.0    # …até aqui
const TOSS_NEAR    = 290.0    # arremessa quando longe

# ── Dano ──
const SWIPE_DAMAGE  = 30.0
const SLAM_DAMAGE   = 26.0
const CHARGE_DAMAGE = 34.0

# ── Tempos base de cada golpe (windup escala por fase) ──
const SWIPE_WINDUP  = 0.34
const SWIPE_LUNGE   = 230.0
const SLAM_WINDUP   = 0.46
const CHARGE_WINDUP = 0.46
const CHARGE_SPEED  = 250.0
const CHARGE_DUR    = 0.72
const SUMMON_WINDUP = 0.55
const TOSS_WINDUP   = 0.40

# ── Cooldowns por golpe (além do gate global entre ataques) ──
const SUMMON_CD     = 9.0
const TOSS_CD       = 3.2
const CHARGE_CD     = 3.0

const DamageNumber  = preload("res://scenes/effects/damage_number.tscn")
const GoblinScene   = preload("res://scenes/enemies/goblin.tscn")
const OgreShockwave = preload("res://scenes/enemies/ogre_shockwave.tscn")
const GoblinArrow   = preload("res://scenes/enemies/goblin_arrow.tscn")
const BossBeam      = preload("res://scenes/enemies/boss_beam.tscn")

# ── Facho de energia (braço mutante) — canal contínuo; estoura escudo do Will ──
const BEAM_WINDUP = 0.70
const BEAM_DUR    = 3.0
const BEAM_CD     = 6.0
const BEAM_NEAR   = 120.0
const BEAM_FAR    = 560.0

@onready var hp_bar = $HPBar
@onready var sprite = $Sprite2D

signal boss_hp_changed(ratio: float)
signal boss_died

var hp: float = MAX_HP
var phase: Phase = Phase.ONE
var facing: float = -1.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var player: Node = null
var _alerted: bool = false

var _state: int = St.IDLE
var _move: String = ""
var _t: float = 0.0          # timer do estado atual
var _global_cd: float = 1.0  # gate entre ataques
var _summon_cd: float = 4.0
var _toss_cd: float = 2.0
var _charge_cd: float = 1.5
var _beam_cd: float = 3.0
var _beam: Node = null
var _charge_hit: bool = false
var _swipe_hits: int = 0     # p/ duplo golpe na fase 3
var _base_mod: Color = Color.WHITE
var _minions: Array = []

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")
	var tex := SpriteSetup.get_texture("goblin_mutant")
	if tex:
		sprite.texture = tex
		sprite.modulate = Color.WHITE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	GameState.time_stop_started.connect(_on_time_stop)
	GameState.time_stop_ended.connect(_on_time_resume)
	boss_hp_changed.emit(1.0)

# ── Tuning por fase ──────────────────────────────────────────────────────────
func _global_gate() -> float:
	match phase:
		Phase.THREE: return 0.85
		Phase.TWO:   return 1.20
		_:           return 1.65

func _windup_mult() -> float:
	match phase:
		Phase.THREE: return 0.70
		Phase.TWO:   return 0.86
		_:           return 1.0

func _walk() -> float:
	match phase:
		Phase.THREE: return WALK_SPEED * 1.5
		Phase.TWO:   return WALK_SPEED * 1.2
		_:           return WALK_SPEED

func _minion_cap() -> int:
	return 3 if phase == Phase.THREE else (3 if phase == Phase.TWO else 2)

# ── Loop principal ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if is_dead or GameState.time_stopped:
		if knockback.length() > 0.0:
			velocity = knockback
			move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if knockback.length() > 100.0:
		velocity.x = knockback.x
		move_and_slide()
		return

	_global_cd = maxf(_global_cd - delta, 0.0)
	_summon_cd = maxf(_summon_cd - delta, 0.0)
	_toss_cd   = maxf(_toss_cd   - delta, 0.0)
	_charge_cd = maxf(_charge_cd - delta, 0.0)
	_beam_cd   = maxf(_beam_cd   - delta, 0.0)

	match _state:
		St.IDLE:    _tick_idle(delta)
		St.WINDUP:  _tick_windup(delta)
		St.ACTIVE:  _tick_active(delta)
		St.RECOVER: _tick_recover(delta)

	move_and_slide()

func _tick_idle(delta: float) -> void:
	if not player or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, _walk() * 4.0 * delta * 60.0)
		return
	var dist := global_position.distance_to(player.global_position)
	var dir := signf(player.global_position.x - global_position.x)
	if dir != 0.0:
		facing = dir
		sprite.flip_h = facing < 0
	if dist > DETECT_RANGE:
		velocity.x = move_toward(velocity.x, 0.0, _walk() * 6.0 * delta)
		return
	if not _alerted:
		_alerted = true
		_show_alert()
	# Pronto pra atacar?
	if _global_cd <= 0.0:
		var m := _choose_move(dist)
		if m != "":
			_enter_windup(m)
			return
	# Senão, reposiciona andando até o player.
	velocity.x = facing * _walk()

# ── Árvore de decisão ────────────────────────────────────────────────────────
func _choose_move(dist: float) -> String:
	var pool: Array = []   # [nome, peso]
	if dist <= SWIPE_RANGE:
		pool.append(["swipe", 4.0])
		pool.append(["slam", 2.0])
	elif dist <= SLAM_RANGE:
		pool.append(["slam", 3.0])
		pool.append(["swipe", 1.0])
	if dist >= CHARGE_NEAR and dist <= CHARGE_FAR and _charge_cd <= 0.0:
		pool.append(["charge", 3.0 if phase != Phase.ONE else 2.0])
	if dist >= TOSS_NEAR and _toss_cd <= 0.0:
		pool.append(["toss", 2.5])
	if phase != Phase.ONE and dist >= BEAM_NEAR and dist <= BEAM_FAR and _beam_cd <= 0.0:
		pool.append(["beam", 2.2])
	if _summon_cd <= 0.0 and _alive_minions() < _minion_cap():
		pool.append(["summon", 2.5])
	if pool.is_empty():
		return ""
	# Sorteio ponderado.
	var total := 0.0
	for e in pool: total += e[1]
	var r := randf() * total
	for e in pool:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return pool[0][0]

# ── WINDUP ───────────────────────────────────────────────────────────────────
func _enter_windup(m: String) -> void:
	_move = m
	_state = St.WINDUP
	velocity.x = 0.0
	match m:
		"swipe":  _t = SWIPE_WINDUP * _windup_mult()
		"slam":   _t = SLAM_WINDUP * _windup_mult()
		"charge": _t = CHARGE_WINDUP * _windup_mult()
		"summon": _t = SUMMON_WINDUP
		"toss":   _t = TOSS_WINDUP * _windup_mult()
		"beam":   _t = BEAM_WINDUP
	AudioManager.play("stomp" if m in ["slam", "charge"] else "detect", randf_range(0.7, 0.9))
	# pequeno "encolher" de antecipação
	sprite.scale = Vector2(0.94, 1.08)

func _tick_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _walk() * 10.0 * delta)
	sprite.modulate = _telegraph_color()   # mantém o aviso visível mesmo se apanhar
	_t -= delta
	if _t <= 0.0:
		_enter_active()

func _telegraph_color() -> Color:
	match _move:
		"summon": return Color(0.8, 2.0, 0.9)    # verde: chamando capangas
		"slam":   return Color(2.0, 0.7, 0.35)
		"toss":   return Color(2.0, 1.2, 0.5)
		"beam":   return Color(1.5, 0.7, 2.0)    # púrpura: carregando o facho mutante
		_:        return Color(2.0, 0.95, 0.5)    # swipe/charge: laranja quente

# ── ACTIVE (o golpe acontece) ────────────────────────────────────────────────
func _enter_active() -> void:
	_state = St.ACTIVE
	sprite.modulate = _base_mod
	sprite.scale = Vector2.ONE
	match _move:
		"swipe":  _begin_swipe()
		"slam":   _do_slam()
		"charge": _begin_charge()
		"summon": _do_summon()
		"toss":   _do_toss()
		"beam":   _begin_beam()

func _tick_active(delta: float) -> void:
	_t -= delta
	if _move == "beam":
		# Canaliza parado, encarando a Soph; o nó do facho segue o braço sozinho.
		velocity.x = move_toward(velocity.x, 0.0, _walk() * 10.0 * delta)
	if _move == "charge":
		velocity.x = facing * CHARGE_SPEED
		# acerta o player UMA vez ao passar por ele
		if not _charge_hit and player and is_instance_valid(player):
			if global_position.distance_to(player.global_position) < 70.0:
				_charge_hit = true
				_hit_player(CHARGE_DAMAGE)
		if is_on_wall():
			_t = 0.0
			VFX.burst(global_position + Vector2(facing * 30, 0), get_parent(), Color(0.7, 0.6, 0.4), 14, 120.0, 60.0)
			if player and is_instance_valid(player) and player.has_method("shake"):
				player.shake(9.0, 0.3)
	if _t <= 0.0:
		_enter_recover()

func _enter_recover() -> void:
	_state = St.RECOVER
	velocity.x = 0.0
	sprite.modulate = _base_mod   # limpa o brilho de canal do facho, se houver
	# Recuperação maior depois de golpes pesados → janela de contra-ataque (justo).
	match _move:
		"charge": _t = 0.7
		"slam":   _t = 0.6
		"summon": _t = 0.5
		_:        _t = 0.35

func _tick_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _walk() * 8.0 * delta)
	_t -= delta
	if _t <= 0.0:
		_state = St.IDLE
		_global_cd = _global_gate()

# ── Golpes ───────────────────────────────────────────────────────────────────
func _begin_swipe() -> void:
	_charge_hit = false
	_t = 0.28
	velocity.x = facing * SWIPE_LUNGE
	AudioManager.play("enemy_attack", randf_range(0.7, 0.85))
	var fist := global_position + Vector2(facing * 52.0, -6.0)
	VFX.hit_spark(fist, get_parent(), facing)
	VFX.burst(fist, get_parent(), Color(0.55, 0.25, 0.5), 12, 90.0, 30.0)
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= SWIPE_RANGE:
			_hit_player(SWIPE_DAMAGE)
	# Fase 3: golpe duplo (segundo tapa logo após).
	_swipe_hits += 1
	if phase == Phase.THREE and _swipe_hits < 2:
		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(self) and not is_dead and _state == St.ACTIVE:
			facing = signf(player.global_position.x - global_position.x) if (player and is_instance_valid(player)) else facing
			sprite.flip_h = facing < 0
			_begin_swipe()
	else:
		_swipe_hits = 0

func _do_slam() -> void:
	_t = 0.3
	AudioManager.play("stomp")
	sprite.scale = Vector2(1.2, 0.78)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.25)
	if player and is_instance_valid(player) and player.has_method("shake"):
		player.shake(14.0, 0.45)
	var base := global_position + Vector2(0, 44)
	VFX.ground_burst(base, get_parent(), Color(0.55, 0.42, 0.20), 24)
	VFX.ring(base, get_parent(), Color(0.85, 0.55, 0.20, 0.85), 70.0, 0.45)
	_spawn_shockwave(1.0)
	_spawn_shockwave(-1.0)
	if phase != Phase.ONE:           # fase 2+: onda dupla mais cadenciada
		_spawn_shockwave(1.0, 36.0)
		_spawn_shockwave(-1.0, 36.0)
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= SLAM_RANGE:
			_hit_player(SLAM_DAMAGE)

func _begin_charge() -> void:
	_charge_hit = false
	_charge_cd = CHARGE_CD
	_t = CHARGE_DUR
	AudioManager.play("roar")
	VFX.burst(global_position + Vector2(0, -20), get_parent(), Color(0.7, 0.25, 0.5), 10, 70.0, 20.0)

func _do_summon() -> void:
	_t = 0.4
	_summon_cd = SUMMON_CD
	AudioManager.play("roar")
	var n := 2 if phase != Phase.ONE else 1
	for i in n:
		if _alive_minions() >= _minion_cap():
			break
		var g = GoblinScene.instantiate()
		get_parent().add_child(g)
		g.global_position = global_position + Vector2(facing * randf_range(20, 50), -30 - i * 8)
		_minions.append(g)
		VFX.burst(g.global_position, get_parent(), Color(0.4, 0.9, 0.3), 12, 80.0, 20.0)
		VFX.ring(g.global_position, get_parent(), Color(0.5, 1.0, 0.4, 0.7), 26.0, 0.3)

func _do_toss() -> void:
	_t = 0.3
	_toss_cd = TOSS_CD
	AudioManager.play("enemy_attack", randf_range(0.6, 0.75))
	var n := 2 if phase == Phase.THREE else 1
	for i in n:
		var arrow = GoblinArrow.instantiate()
		arrow.direction = facing
		arrow.position = global_position + Vector2(facing * 40.0, -20.0 + i * 12.0)
		get_parent().add_child(arrow)
	VFX.burst(global_position + Vector2(facing * 40, -16), get_parent(), Color(0.6, 0.3, 0.5), 8, 60.0, 20.0)

func _begin_beam() -> void:
	# Solta o facho contínuo pelo braço mutante (dura BEAM_DUR; segue o braço).
	_beam_cd = BEAM_CD
	_t = BEAM_DUR
	if player and is_instance_valid(player):
		facing = signf(player.global_position.x - global_position.x)
		if facing == 0.0: facing = -1.0
		sprite.flip_h = facing < 0
	AudioManager.play("roar", 0.85)
	sprite.modulate = Color(1.5, 0.85, 1.7)   # braço incandescente durante o canal
	VFX.burst(global_position + Vector2(facing * 50, -10), get_parent(), Color(0.7, 1.0, 0.5), 14, 90.0, 20.0)
	VFX.ring(global_position + Vector2(facing * 50, -10), get_parent(), Color(0.6, 0.95, 1.0, 0.8), 28.0, 0.35)
	var b = BossBeam.instantiate()
	b.direction = facing
	b.shooter = self
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(facing * 56.0, -10.0)
	_beam = b

func force_beam() -> void:
	# Dispara o facho IMEDIATAMENTE (usado no test room p/ sincronizar vários bosses).
	if is_dead:
		return
	_state = St.ACTIVE
	_move = "beam"
	sprite.scale = Vector2.ONE
	_begin_beam()

func _spawn_shockwave(dir: float, offset: float = 8.0) -> void:
	var wave = OgreShockwave.instantiate()
	wave.direction = dir
	wave.global_position = global_position + Vector2(dir * offset, 36.0)
	get_parent().add_child(wave)

func _hit_player(dmg: float) -> void:
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(dmg, global_position)

func _alive_minions() -> int:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.is_dead)
	return _minions.size()

# ── Dano recebido ────────────────────────────────────────────────────────────
var _armless: bool = false

## Chamado pelo Gus (Convoke) ao arrancar o braço — o Boss fica sem o braço.
func lose_arm() -> void:
	if _armless:
		return
	_armless = true
	var t := SpriteSetup.get_texture("goblin_mutant_noarm")
	if t:
		sprite.texture = t

func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	# SUPER-ARMADURA: apanhar NÃO cancela o ataque do boss (não dá pra travar).
	var crit := HitZones.is_head_hit(self, from)   # cabeça = crítico (2x)
	if crit:
		amount *= HitZones.CRIT_MULT
	hp -= amount
	if is_instance_valid(hp_bar): hp_bar.show_damage(hp / MAX_HP)
	boss_hp_changed.emit(clampf(hp / MAX_HP, 0.0, 1.0))

	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.global_position = global_position + Vector2(0, -64)
	if crit:
		dmg.setup(amount, HitZones.CRIT_COLOR, true)
	else:
		dmg.setup(amount)

	var kdir = signf(global_position.x - from.x) if from != Vector2.ZERO else 1.0
	if kdir == 0.0: kdir = 1.0
	knockback = Vector2(kdir * 90.0, -30.0)   # boss é pesadíssimo
	AudioManager.play("hit", randf_range(0.78, 0.92))
	var killing := hp <= 0.0
	# squash=false: o boss anima a própria escala (golpes) — não conflitar.
	VFX.enemy_impact(sprite, global_position, get_parent(), kdir, amount, killing, -52.0, false)
	_flash()
	_check_phase()
	if killing:
		_die()

func _flash() -> void:
	# Não usa await (pode estar em qualquer estado) — tween curto que volta à base.
	if is_dead: return
	sprite.modulate = Color(2.6, 2.6, 2.6)
	create_tween().tween_property(sprite, "modulate", _base_mod, 0.14)

func _check_phase() -> void:
	var r := hp / MAX_HP
	if phase == Phase.ONE and r <= 0.6:
		phase = Phase.TWO
		_enrage("A mutação pulsa — ele fica mais rápido!", Color(1.15, 0.95, 0.95))
	elif phase == Phase.TWO and r <= 0.3:
		phase = Phase.THREE
		_enrage("ENFURECIDO! Olhos em brasa!", Color(1.35, 0.72, 0.70))

func _enrage(_msg: String, tint: Color) -> void:
	_base_mod = tint
	_global_cd = 0.5   # janela curta antes do próximo golpe
	AudioManager.play("roar")
	if player and is_instance_valid(player) and player.has_method("shake"):
		player.shake(10.0, 0.5)
	VFX.burst(global_position + Vector2(0, -20), get_parent(), Color(1.0, 0.4, 0.2), 26, 140.0, 40.0)
	VFX.ring(global_position + Vector2(0, -20), get_parent(), Color(1.0, 0.5, 0.2, 0.85), 80.0, 0.5)
	create_tween().tween_property(sprite, "modulate", _base_mod, 0.2)

# ── Morte ────────────────────────────────────────────────────────────────────
func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	GameState.enemy_died()
	boss_hp_changed.emit(0.0)
	boss_died.emit()
	sprite.modulate = Color(0.5, 0.45, 0.4, 0.9)
	AudioManager.play("enemy_die")
	AudioManager.play("boss_appear", 0.6)
	if player and is_instance_valid(player) and player.has_method("shake"):
		player.shake(24.0, 1.1)
	# Explosão multi-camada (a mutação se desfaz).
	VFX.burst(global_position, get_parent(), Color(0.4, 0.7, 0.2), 60, 230.0, 130.0)
	VFX.burst(global_position, get_parent(), Color(0.6, 0.25, 0.55), 30, 150.0, 80.0)
	VFX.ring(global_position, get_parent(), Color(0.6, 1.0, 0.4, 0.9), 110.0, 0.6)
	VFX.ring(global_position, get_parent(), Color(0.7, 0.3, 0.6, 0.7), 170.0, 0.85)
	VFX.ground_burst(global_position + Vector2(0, 40), get_parent(), Color(0.5, 0.4, 0.2), 30)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.3, 0.5), 0.15)
	tw.parallel().tween_property(sprite, "rotation", randf_range(-0.5, 0.5), 0.5)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tw.finished
	if is_instance_valid(self):
		queue_free()

# ── Apoio ────────────────────────────────────────────────────────────────────
func _show_alert() -> void:
	AudioManager.play("boss_appear")
	var lbl := Label.new()
	lbl.text = "!!!"
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.05))
	lbl.position = Vector2(-14, -104)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(2.2, 2.2), 0.12)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.22)
	tw.tween_interval(0.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)

func _on_time_stop() -> void:
	if is_dead: return
	sprite.create_tween().tween_property(sprite, "modulate", Color(0.55, 0.72, 1.20), 0.14)

func _on_time_resume() -> void:
	if is_dead: return
	sprite.create_tween().tween_property(sprite, "modulate", _base_mod, 0.18)

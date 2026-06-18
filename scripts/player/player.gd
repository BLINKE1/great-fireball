extends CharacterBody2D

signal fall_danger(is_dangerous: bool)
const WALK_SPEED = 110.0          # default (caminhar)
const RUN_SPEED  = 220.0          # com SHIFT segurado (correr)
const SPEED      = RUN_SPEED      # alias legado (dash/squash-stretch/lean)
const JUMP_VELOCITY = -420.0
const GRAVITY = 980.0

# ── Game feel do pulo (afináveis — medidos pelo tools/feel_bench.py) ────────
# Pulo variável: soltar o botão cedo corta a subida → controle de altura.
const JUMP_CUT_MULT      = 0.45   # ao soltar subindo, velocity.y *= isto
# Gravidade de queda assimétrica: cai mais pesado que sobe → pulo "gostoso".
const FALL_GRAVITY_MULT  = 1.45   # gravidade extra quando descendo
# Apex hang: gravidade reduzida no topo do arco → sensação premium de controle.
const APEX_THRESHOLD     = 55.0   # |velocity.y| abaixo disto = "no apex"
const APEX_GRAVITY_MULT  = 0.55   # gravidade reduzida perto do topo

# ── Arte HD da Soph (conjunto "dream": alta resolucao, suave) ──────────────
# Experimental: destoa do pixel-art do resto do jogo. Desligue para voltar ao
# pixel-art 32x64. Os assets HD ficam em assets/sprites/player/soph_hd_*.png
# e sao gerados por tools/art_director/soph_dream.py --apply-game.
const USE_HD_SOPH := true  # arte HD gerada (Pollinations) com downscale estilo Hollow Knight
const HD_SCALE := 0.43            # set1 c/ cajado: personagem ocupa 151px do frame de 192 → ~65px na tela
const HD_OFFSET := Vector2(0, -8)  # sobe o sprite: pés do frame (base do 192px) no chão com a escala nova

# Compensação per-anim do HD: os PNGs do Pollinations vieram com bbox/orientação
# inconsistentes entre anims. Sem isto, ao andar/correr a Soph fica MAIOR (bbox
# maior no canvas → ocupa mais tela na mesma escala) e walk/cast/slash/jump/
# fall/hurt aparecem INVERTIDAS (foram geradas olhando pra esquerda na fonte).
# Plano B = regerar com bbox/orientação normalizadas e zerar estas tabelas.
const HD_BASE_BBOX := 150.0                       # altura alvo (idle ≈ 150px no canvas 192)
const HD_FRAME_H   := 192.0
const HD_ANIM_BBOX := {                           # altura do conteúdo (alpha>0) por anim
	"idle":  150.0,
	"walk":  167.0,
	"run":   178.0,
	"jump":  190.0,
	"fall":  190.0,
	"hurt":  190.0,
	"cast":  190.0,
	"slash": 190.0,
}
const HD_ANIM_NATIVE_LEFT := {                    # anims desenhadas olhando p/ esquerda na fonte
	"idle":  true,
	"walk":  true,
	"jump":  true,
	"fall":  true,
	"hurt":  true,
	"cast":  true,
	"slash": true,
	# run: maioria dos frames olha pra direita (run_2 destoa, mas é minoria).
}

const MAGIC_MISSILE_COST  = 15.0
const MAGIC_MISSILE_CD    = 0.18
const TIME_STOP_COST      = 30.0
const TIME_STOP_DURATION  = 3.0
const HEAL_COST           = 40.0
const HEAL_AMOUNT         = 30.0
const DASH_COST           = 20.0
const DASH_SPEED          = 500.0
const DASH_DURATION       = 0.18
const DASH_COOLDOWN       = 0.5
const SWORD_COOLDOWN      = 0.4
const SWORD_FLASH         = 0.1
const SWORD_LUNGE         = 190.0  # passo pra frente no golpe (peso/compromisso)
const MELEE_MANA_GAIN     = 12.0   # mana recuperada por golpe de cajado que acerta

# ── Mira do Magic Missile (estilo Dead Eye / Red Dead) ─────────────────────
# Segura a tecla -> entra em câmera lenta + linha que PIVOTA na ponta do cajado;
# mouse (ou setas ↑/↓) gira o ângulo; soltar dispara naquele ângulo. Qualquer
# ângulo 360° vale, a linha nunca sai da ponta do cajado.
const AIM_TIME_SCALE  = 0.30       # quão lento fica o tempo enquanto mira
const AIM_LINE_LEN    = 130.0      # comprimento da linha de mira (px)
const AIM_ROT_SPEED   = 2.6        # rad/s ao girar por teclado
const STAFF_TIP       = Vector2(24, -16)  # ponta do cajado relativa ao player

# New missile variants
const MISSILE_SPREAD_COST     = 22.0
const MISSILE_SPREAD_CD       = 0.32
const MISSILE_PIERCING_COST   = 22.0
const MISSILE_PIERCING_CD     = 0.28
const MISSILE_GIANT_COST      = 50.0
const MISSILE_GIANT_CD        = 1.60
const MISSILE_CURVED_COST     = 18.0
const MISSILE_CURVED_CD       = 0.55
const MAGIC_SHIELD_COST       = 35.0
const MAGIC_SHIELD_DURATION   = 3.5
const MAGIC_SHIELD_CD         = 6.0

# Convoke — convoca a Juju (fada) pra adormecer os inimigos. Custo alto e
# cooldown longo: é uma "ultimate" de suporte, não um spam.
const CONVOKE_COST            = 45.0
const CONVOKE_CD              = 12.0
# Convoke do Will — aliado defensivo (escudo gigante). Ultimate de defesa.
const CONVOKE_WILL_COST       = 50.0
const CONVOKE_WILL_CD         = 14.0
# Convoke do Gus — aliado dagger/aventureiro (ofensivo, assassino de mobs).
const CONVOKE_GUS_COST        = 50.0
const CONVOKE_GUS_CD          = 14.0
# Convoke da Di — elfa Sentinela (arqueira; dano à distância / multi-alvo).
const CONVOKE_DI_COST         = 50.0
const CONVOKE_DI_CD           = 14.0
# Convoke do Gui Fenrir — rush de espadão (espetinho) + lobisomem feroz.
const CONVOKE_GUI_COST        = 55.0
const CONVOKE_GUI_CD          = 15.0
# Convokes da família (Rose=gelo, Zé=fogo) — ultimates de NG+ (overkill geral).
const CONVOKE_ROSE_COST       = 70.0
const CONVOKE_ROSE_CD         = 25.0
const CONVOKE_ZE_COST         = 70.0
const CONVOKE_ZE_CD           = 25.0

# Fall damage thresholds (pixels fallen from apex/start to landing)
const FALL_SAFE   = 220.0   # below this: no damage
const FALL_LIGHT  = 380.0   # 15 HP
const FALL_MEDIUM = 560.0   # 30 HP
const FALL_HEAVY  = 760.0   # 55 HP (above: 100 HP, usually lethal)

const IFRAME_DURATION   = 1.0
const KNOCKBACK_FORCE   = 300.0
const COYOTE_TIME       = 0.12
const JUMP_BUFFER_TIME  = 0.12

const MagicMissile    = preload("res://scenes/spells/magic_missile.tscn")
const MissileSpread   = preload("res://scenes/spells/missile_spread.tscn")
const MissilePiercing = preload("res://scenes/spells/missile_piercing.tscn")
const MissileGiant    = preload("res://scenes/spells/missile_giant.tscn")
const MissileCurved   = preload("res://scenes/spells/missile_curved.tscn")
const SwordSlash      = preload("res://scenes/player/sword_slash.tscn")
const DamageNumber    = preload("res://scenes/effects/damage_number.tscn")
const Juju            = preload("res://scenes/spells/juju.tscn")
const WillAlly        = preload("res://scenes/spells/will.tscn")
const GusAlly         = preload("res://scenes/spells/gus.tscn")
const DiAlly          = preload("res://scenes/spells/di.tscn")
const GuiAlly         = preload("res://scenes/spells/gui.tscn")
const RoseAlly        = preload("res://scenes/spells/rose.tscn")
const ZeAlly          = preload("res://scenes/spells/ze.tscn")

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var hair: Sprite2D            = $Hair
@onready var mana: Node                = $Mana
@onready var hp: Node         = $HP
@onready var camera: Camera2D = $Camera2D

var facing: float = 1.0
var iframe_timer: float = 0.0
var _step_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var sword_timer: float = 0.0
var _attack_pose: String = ""        # "cast" (cajado) / "slash" (lâmina) durante o ataque
var _attack_pose_timer: float = 0.0

# Mira do Magic Missile
var is_aiming: bool = false
var _aim_angle: float = 0.0
var _aim_line: Line2D = null
var _aim_dot: Polygon2D = null
var _last_mouse: Vector2 = Vector2.ZERO
var attack_flash_timer: float = 0.0
var is_dashing: bool = false
var is_dead: bool = false
var is_cutscene: bool = false
var was_on_floor: bool = false
var spawn_position: Vector2
var base_modulate: Color
var jumps_remaining: int = 1
var _ghost_timer: float = 0.0

# Missile cooldown timers
var magic_missile_cd: float = 0.0
var missile_spread_cd: float = 0.0
var missile_piercing_cd: float = 0.0
var missile_giant_cd: float = 0.0
var missile_curved_cd: float = 0.0
var convoke_cd: float = 0.0
var convoke_will_cd: float = 0.0
var convoke_gus_cd: float = 0.0
var convoke_di_cd: float = 0.0
var convoke_gui_cd: float = 0.0
var convoke_rose_cd: float = 0.0
var convoke_ze_cd: float = 0.0

# Shield state
var shield_timer: float = 0.0
var shield_cd_timer: float = 0.0
var _shield_active: bool = false
var _shield_visual: Node2D = null

# Burn state
var _burn_timer: float = 0.0
var _burn_dps: float = 0.0
var _burn_tick: float = 0.0
var _burn_flash: float = 0.0

# Fall tracking
var _fall_start_y:      float = 0.0
var _air_hike_y:        float = 0.0
var _prev_vy:           float = 0.0
var _tracking_fall:     bool  = false
var _air_hiked:         bool  = false
var _was_fall_dangerous: bool = false
var _fall_trail_timer:  float = 0.0

# Screen shake + camera state
var _shake_intensity: float = 0.0
var _shake_duration: float  = 0.0
var _heartbeat_timer: float = 0.0
var _look_ahead: float      = 0.0

# Squash & stretch
var _squash: Vector2 = Vector2.ONE
var _lean: float = 0.0           # inclinação (skew) na direção do movimento
var _last_facing: float = 1.0    # p/ detectar virada e dar um "pop"

# Escala base do sprite (1.0 no pixel-art, HD_SCALE no HD). _update_visuals
# multiplica isso pela squash todo frame; sem essa base, a squash zerava
# o HD_SCALE e a Soph HD aparecia em tamanho nativo (gigante).
var _base_scale: Vector2 = Vector2.ONE

var _mana_level: int = 5
var _mana_ratio: float = 1.0

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position

	sprite.sprite_frames = _build_soph_frames()
	sprite.play("idle_5")
	if USE_HD_SOPH:
		# arte HD: amostragem linear (suave) + escala/offset p/ caber no hitbox
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_base_scale = Vector2(HD_SCALE, HD_SCALE)
		sprite.scale = _base_scale
		sprite.position = HD_OFFSET
	else:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_base_scale = Vector2.ONE

	hair.hide()  # full-body sprites include hair

	base_modulate = sprite.modulate
	mana.mana_changed.connect(_on_mana_changed)
	hp.died.connect(_on_died)
	mana.regen_rate = 4.0
	mana.out_of_combat_delay = 2.0

	var ShieldVisual = load("res://scripts/player/shield_visual.gd")
	_shield_visual = ShieldVisual.new()
	_shield_visual.position = Vector2(0, -18)
	add_child(_shield_visual)

	_setup_aim_visual()

func _setup_aim_visual() -> void:
	# Linha de mira que pivota na ponta do cajado (escondida até mirar).
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(0.35, 0.9, 1.0, 0.85)
	_aim_line.points = PackedVector2Array([Vector2.ZERO, Vector2(AIM_LINE_LEN, 0)])
	_aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_line.z_index = 5
	_aim_line.visible = false
	add_child(_aim_line)
	# ponto/retícula na ponta da linha
	_aim_dot = Polygon2D.new()
	var r := 4.0
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * i / 10.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	_aim_dot.polygon = pts
	_aim_dot.color = Color(0.6, 0.95, 1.0, 0.95)
	_aim_dot.z_index = 6
	_aim_dot.visible = false
	add_child(_aim_dot)

func _physics_process(delta: float) -> void:
	_tick_shake(delta)

	if is_dead:
		return

	if is_cutscene or GameState.dialogue_active:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3.0)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	_tick_timers(delta)
	_check_landing()

	if is_aiming:
		_update_aim(delta)
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0, SPEED * 3.0)
		_update_visuals()
		move_and_slide()
		return

	if is_dashing:
		velocity.x = facing * DASH_SPEED
		velocity.y = 0.0
		_update_visuals()
		move_and_slide()
		return

	_apply_gravity(delta)
	_tick_fall()
	_handle_jump()
	_handle_movement()
	_handle_spells()
	_update_visuals()
	move_and_slide()

func _tick_timers(delta: float) -> void:
	_prev_vy            = velocity.y
	_squash             = _squash.lerp(Vector2.ONE, delta * 14.0)
	iframe_timer        = max(iframe_timer        - delta, 0.0)
	jump_buffer_timer   = max(jump_buffer_timer   - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	sword_timer         = max(sword_timer         - delta, 0.0)
	_attack_pose_timer  = max(_attack_pose_timer  - delta, 0.0)
	attack_flash_timer  = max(attack_flash_timer  - delta, 0.0)
	_ghost_timer        = max(_ghost_timer        - delta, 0.0)
	_step_timer         = max(_step_timer         - delta, 0.0)
	magic_missile_cd    = max(magic_missile_cd    - delta, 0.0)
	missile_spread_cd   = max(missile_spread_cd   - delta, 0.0)
	missile_piercing_cd = max(missile_piercing_cd - delta, 0.0)
	missile_giant_cd    = max(missile_giant_cd    - delta, 0.0)
	missile_curved_cd   = max(missile_curved_cd   - delta, 0.0)
	convoke_cd          = max(convoke_cd          - delta, 0.0)
	convoke_will_cd     = max(convoke_will_cd     - delta, 0.0)
	convoke_gus_cd      = max(convoke_gus_cd      - delta, 0.0)
	convoke_di_cd       = max(convoke_di_cd       - delta, 0.0)
	convoke_gui_cd      = max(convoke_gui_cd      - delta, 0.0)
	convoke_rose_cd     = max(convoke_rose_cd     - delta, 0.0)
	convoke_ze_cd       = max(convoke_ze_cd       - delta, 0.0)
	shield_cd_timer     = max(shield_cd_timer     - delta, 0.0)

	# Shield expiry
	if _shield_active:
		shield_timer -= delta
		if shield_timer <= 0.0:
			_shield_active = false
			if _shield_visual:
				_shield_visual.deactivate()
			AudioManager.play("shield_break")
			VFX.ring(global_position + Vector2(0, -18), get_parent(),
					Color(0.30, 0.68, 1.0, 0.70), 36.0, 0.32)
			VFX.burst(global_position + Vector2(0, -18), get_parent(),
					Color(0.45, 0.78, 1.0), 10, 60.0, 45.0)

	# Burn damage-over-time (shield blocks burn ticks)
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick  -= delta
		_burn_flash  = max(_burn_flash - delta * 3.0, 0.0)
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			if not _shield_active:
				hp.take_damage(_burn_dps * 0.5)
			VFX.burst(global_position + Vector2(0, -10), get_parent(), Color(1.0, 0.45, 0.06), 3, 28.0, 20.0)
			_burn_flash = 0.18
		if _burn_timer <= 0.0:
			_burn_dps = 0.0

	# Critical HP heartbeat
	if hp.get_ratio() < 0.25 and not is_dead:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = 1.05
			AudioManager.play("heartbeat", randf_range(0.90, 1.04))
	else:
		_heartbeat_timer = 0.0

	if is_on_floor() and abs(velocity.x) > 20.0 and not is_dashing and _step_timer <= 0.0:
		_step_timer = 0.27
		AudioManager.play("step", randf_range(0.82, 1.18))
		# Pufezinho de poeira atrás do pé (toque de game feel ao correr).
		VFX.burst(global_position + Vector2(-facing * 6.0, 16.0), get_parent(),
				Color(0.70, 0.58, 0.42, 0.55), 3, 24.0, -8.0)
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		elif _ghost_timer <= 0.0:
			_ghost_timer = 0.05
			_spawn_dash_ghost()
	if is_on_floor():
		coyote_timer    = COYOTE_TIME
		jumps_remaining = _max_air_jumps()
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

func _tick_shake(delta: float) -> void:
	_look_ahead = lerpf(_look_ahead, facing * 88.0, delta * 3.8)
	if _shake_duration > 0.0:
		_shake_duration -= delta
		camera.offset = Vector2(
			_look_ahead + randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		camera.offset = Vector2(_look_ahead, 0.0)

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration  = duration

func _check_landing() -> void:
	if is_on_floor() and not was_on_floor:
		AudioManager.play("land")
		_squash = Vector2(1.28, 0.74)
		VFX.burst(global_position + Vector2(0, 16), get_parent(),
				Color(0.70, 0.58, 0.42, 0.85), 7, 42.0, -15.0)
		_on_landed()
	was_on_floor = is_on_floor()

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := GRAVITY
	if velocity.y > 0.0:
		# Descendo: queda mais pesada que a subida (pulo menos "flutuante").
		g *= FALL_GRAVITY_MULT
	if absf(velocity.y) < APEX_THRESHOLD:
		# Perto do topo do arco: segura um instante → controle aéreo premium.
		g *= APEX_GRAVITY_MULT
	velocity.y += g * delta

func _max_air_jumps() -> int:
	return 1 if SkillManager.has("double_jump") else 0

# ── Fall tracking ─────────────────────────────────────────────────────────────

func _tick_fall() -> void:
	if is_on_floor():
		if _was_fall_dangerous:
			_was_fall_dangerous = false
			fall_danger.emit(false)
		_fall_trail_timer = 0.0
		return
	# Detect the moment velocity turns downward (jump apex or walking off edge)
	if velocity.y > 0 and _prev_vy <= 0:
		if not _air_hiked:
			_fall_start_y = global_position.y
		_tracking_fall = true

	# Emit fall danger signal for HUD blue vignette
	if _tracking_fall:
		var ref_y := _air_hike_y if _air_hiked else _fall_start_y
		var dist  := global_position.y - ref_y
		var now_dangerous := dist > FALL_SAFE * 0.72
		if now_dangerous != _was_fall_dangerous:
			_was_fall_dangerous = now_dangerous
			fall_danger.emit(now_dangerous)

	# Wind-trail VFX when falling very fast
	if velocity.y > 480.0:
		_fall_trail_timer -= get_physics_process_delta_time()
		if _fall_trail_timer <= 0.0:
			_fall_trail_timer = 0.07
			VFX.burst(global_position + Vector2(randf_range(-6.0, 6.0), 8.0),
					get_parent(), Color(0.72, 0.68, 0.88, 0.55), 2, 18.0, -55.0)

func clear_burn() -> void:
	_burn_timer = 0.0
	_burn_dps   = 0.0
	_burn_tick  = 0.0
	_burn_flash = 0.0

func _on_landed() -> void:
	if not _tracking_fall: return
	if _was_fall_dangerous:
		_was_fall_dangerous = false
		fall_danger.emit(false)
	var dist: float
	if _air_hiked:
		# Segment 2: from air-hike activation point to final landing
		dist = global_position.y - _air_hike_y
	else:
		# No air-hike: full fall distance from apex
		dist = global_position.y - _fall_start_y
	var dmg := _fall_damage(maxf(dist, 0.0))
	if dmg > 0.0:
		_apply_fall_damage(dmg)
	_tracking_fall = false
	_air_hiked     = false

func _fall_damage(dist: float) -> float:
	if   dist < FALL_SAFE:   return 0.0
	elif dist < FALL_LIGHT:  return 15.0
	elif dist < FALL_MEDIUM: return 30.0
	elif dist < FALL_HEAVY:  return 55.0
	else:                    return 100.0

func _apply_fall_damage(amount: float) -> void:
	if is_dead: return
	hp.take_damage(amount)
	shake(minf(amount * 0.55, 14.0), 0.35)
	AudioManager.play("stomp", randf_range(0.78, 0.96))
	VFX.burst(global_position + Vector2(0, 12), get_parent(),
			Color(0.80, 0.65, 0.40), 12, 72.0, 16.0)
	VFX.ground_burst(global_position + Vector2(0, 10), get_parent(),
			Color(0.65, 0.52, 0.30), 8)
	var dmg_num = DamageNumber.instantiate()
	get_parent().add_child(dmg_num)
	dmg_num.global_position = global_position + Vector2(0, -32)
	dmg_num.setup(amount, Color(0.90, 0.65, 0.22))
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color(1.6, 0.55, 0.18), 0.0)
	tw.tween_property(sprite, "modulate", base_modulate, 0.22)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
		if not is_on_floor() and coyote_timer <= 0.0 and jumps_remaining > 0:
			# Air-hike in a fall: calculate segment 1 damage and start segment 2
			if _tracking_fall and velocity.y > 0:
				var seg1 := global_position.y - _fall_start_y
				var seg1_dmg := _fall_damage(maxf(seg1, 0.0))
				if seg1_dmg > 0.0:
					_apply_fall_damage(seg1_dmg)
				_air_hiked  = true
				_air_hike_y = global_position.y
			velocity.y = JUMP_VELOCITY * 0.85
			jumps_remaining -= 1
			jump_buffer_timer = 0.0
			_squash = Vector2(0.72, 1.30)
			AudioManager.play("double_jump")
			VFX.burst(global_position, get_parent(), Color(0.5, 0.85, 1.0), 12, 65.0, 30.0)
			return
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jumps_remaining = _max_air_jumps()
		_squash = Vector2(0.78, 1.24)
		# Pufezinho de poeira no impulso (juice do pulo de solo).
		VFX.burst(global_position + Vector2(0, 16), get_parent(),
				Color(0.70, 0.58, 0.42, 0.7), 6, 55.0, -12.0)
		# (sem som de pulo: a repetição a cada pulo ficava cansativa)

	# Pulo variável: soltou o botão ainda subindo → corta a subida (pulo baixo).
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULT

func _handle_movement() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var running := Input.is_key_pressed(KEY_SHIFT)
	var spd := RUN_SPEED if running else WALK_SPEED
	if direction != 0:
		velocity.x = direction * spd
		facing = direction
	else:
		velocity.x = move_toward(velocity.x, 0, RUN_SPEED)

func _handle_spells() -> void:
	if Input.is_action_just_pressed("spell_magic_missile"):
		_start_aim()
	if Input.is_action_just_pressed("spell_missile_spread"):
		_cast_missile_spread()
	if Input.is_action_just_pressed("spell_missile_piercing"):
		_cast_missile_piercing()
	if Input.is_action_just_pressed("spell_missile_giant"):
		_cast_missile_giant()
	if Input.is_action_just_pressed("spell_missile_curved"):
		_cast_missile_curved()
	if Input.is_action_just_pressed("spell_magic_shield"):
		_cast_magic_shield()
	if Input.is_action_just_pressed("spell_time_stop"):
		_cast_time_stop()
	if Input.is_action_just_pressed("spell_heal"):
		_cast_heal()
	if Input.is_action_just_pressed("spell_magic_dash"):
		_cast_magic_dash()
	if Input.is_action_just_pressed("spell_convoke"):
		_cast_convoke()
	if Input.is_action_just_pressed("spell_convoke_will"):
		_cast_convoke_will()
	if Input.is_action_just_pressed("spell_convoke_gus"):
		_cast_convoke_gus()
	if Input.is_action_just_pressed("spell_convoke_di"):
		_cast_convoke_di()
	if Input.is_action_just_pressed("spell_convoke_gui"):
		_cast_convoke_gui()
	if Input.is_action_just_pressed("spell_convoke_rose"):
		_cast_convoke_rose()
	if Input.is_action_just_pressed("spell_convoke_ze"):
		_cast_convoke_ze()
	if Input.is_action_just_pressed("attack_sword"):
		_attack_sword()

func _start_aim() -> void:
	if is_aiming: return
	if not SkillManager.has("magic_missile"): return
	if magic_missile_cd > 0.0: return
	if mana.current_mana < MAGIC_MISSILE_COST: return   # gasta só no disparo
	is_aiming = true
	Engine.time_scale = AIM_TIME_SCALE
	_aim_angle = 0.0 if facing >= 0.0 else PI
	_last_mouse = get_global_mouse_position()
	_set_attack_pose("cast", 999.0)
	_refresh_aim_visual()
	_aim_line.visible = true
	_aim_dot.visible = true

func _update_aim(delta: float) -> void:
	_attack_pose = "cast"          # segura a pose de cast enquanto mira
	_attack_pose_timer = 1.0
	if Input.is_action_just_pressed("attack_sword"):   # cancela sem disparar
		_end_aim(); return
	# ângulo: segue o mouse (se mexeu) OU gira por ↑/↓
	var pivot_w := global_position + Vector2(facing * STAFF_TIP.x, STAFF_TIP.y)
	var m := get_global_mouse_position()
	if m.distance_to(_last_mouse) > 1.5:
		_aim_angle = (m - pivot_w).angle()
		_last_mouse = m
	else:
		var rot := Input.get_axis("ui_up", "ui_down")
		if rot != 0.0:   # compensa o time_scale p/ girar em tempo real
			_aim_angle += rot * AIM_ROT_SPEED * (delta / max(Engine.time_scale, 0.001))
	facing = 1.0 if cos(_aim_angle) >= 0.0 else -1.0
	_refresh_aim_visual()
	if Input.is_action_just_released("spell_magic_missile"):
		_fire_aimed_missile()
		_end_aim()

func _refresh_aim_visual() -> void:
	if _aim_line == null: return
	var pivot := Vector2(facing * STAFF_TIP.x, STAFF_TIP.y)
	_aim_line.position = pivot
	_aim_line.rotation = _aim_angle
	_aim_dot.position = pivot + Vector2(cos(_aim_angle), sin(_aim_angle)) * AIM_LINE_LEN

func _fire_aimed_missile() -> void:
	if not mana.spend(MAGIC_MISSILE_COST): return
	magic_missile_cd = MAGIC_MISSILE_CD
	AudioManager.play("missile")
	var missile = MagicMissile.instantiate()
	missile.aim_dir = Vector2(cos(_aim_angle), sin(_aim_angle))
	missile.position = global_position + Vector2(facing * STAFF_TIP.x, STAFF_TIP.y)
	missile.modulate = Nails.tint()
	get_parent().add_child(missile)

func _end_aim() -> void:
	is_aiming = false
	Engine.time_scale = 1.0
	if _aim_line: _aim_line.visible = false
	if _aim_dot: _aim_dot.visible = false

func _cast_magic_missile() -> void:
	if not SkillManager.has("magic_missile"): return
	if magic_missile_cd > 0.0: return
	if not mana.spend(MAGIC_MISSILE_COST): return
	magic_missile_cd = MAGIC_MISSILE_CD
	_set_attack_pose("cast")
	AudioManager.play("missile")
	var missile = MagicMissile.instantiate()
	missile.direction = facing
	missile.position = global_position + Vector2(facing * 24, -16)
	missile.modulate = Nails.tint()
	get_parent().add_child(missile)

func _cast_missile_spread() -> void:
	if not SkillManager.has("missile_spread"): return
	if missile_spread_cd > 0.0: return
	if not mana.spend(MISSILE_SPREAD_COST): return
	missile_spread_cd = MISSILE_SPREAD_CD
	_set_attack_pose("cast")
	AudioManager.play("missile_spread")
	VFX.sparkle(global_position + Vector2(facing * 20, -16), get_parent(), Color(0.80, 0.35, 1.0), 8)
	var angles := [-0.18, 0.18]
	for ang in angles:
		var m = MissileSpread.instantiate()
		m.direction    = facing
		m.angle_offset = ang
		m.position     = global_position + Vector2(facing * 20, -16)
		m.modulate     = Nails.tint()
		get_parent().add_child(m)

func _cast_missile_piercing() -> void:
	if not SkillManager.has("missile_piercing"): return
	if missile_piercing_cd > 0.0: return
	if not mana.spend(MISSILE_PIERCING_COST): return
	missile_piercing_cd = MISSILE_PIERCING_CD
	_set_attack_pose("cast")
	AudioManager.play("missile_piercing")
	var m = MissilePiercing.instantiate()
	m.direction = facing
	m.position  = global_position + Vector2(facing * 24, -16)
	m.modulate  = Nails.tint()
	get_parent().add_child(m)

func _cast_missile_giant() -> void:
	if not SkillManager.has("missile_giant"): return
	if missile_giant_cd > 0.0: return
	if not mana.spend(MISSILE_GIANT_COST): return
	missile_giant_cd = MISSILE_GIANT_CD
	_set_attack_pose("cast", 0.28)
	AudioManager.play("missile_giant")
	shake(3.5, 0.22)
	var m = MissileGiant.instantiate()
	m.direction = facing
	m.position  = global_position + Vector2(facing * 28, -18)
	m.modulate  = Nails.tint()
	get_parent().add_child(m)

func _cast_missile_curved() -> void:
	if not SkillManager.has("missile_curved"): return
	if missile_curved_cd > 0.0: return
	if not mana.spend(MISSILE_CURVED_COST): return
	missile_curved_cd = MISSILE_CURVED_CD
	_set_attack_pose("cast")
	AudioManager.play("missile_curved")
	VFX.sparkle(global_position + Vector2(facing * 18, -20), get_parent(), Color(0.60, 0.15, 1.0), 6)
	var m = MissileCurved.instantiate()
	m.direction = facing
	m.position  = global_position + Vector2(facing * 20, -22)
	m.modulate  = Nails.tint()
	get_parent().add_child(m)

func _cast_magic_shield() -> void:
	if not SkillManager.has("magic_shield"): return
	if _shield_active or shield_cd_timer > 0.0: return
	if not mana.spend(MAGIC_SHIELD_COST): return
	_shield_active = true
	shield_timer = MAGIC_SHIELD_DURATION
	shield_cd_timer = MAGIC_SHIELD_CD
	AudioManager.play("shield_activate")
	if _shield_visual:
		_shield_visual.activate()
	VFX.ring(global_position + Vector2(0, -18), get_parent(), Color(0.30, 0.68, 1.0, 0.80), 32.0, 0.35)

func _cast_time_stop() -> void:
	if not SkillManager.has("time_stop"): return
	if not mana.spend(TIME_STOP_COST): return
	AudioManager.play("time_stop")
	GameState.start_time_stop(TIME_STOP_DURATION)
	VFX.burst(global_position, get_parent(), Color(0.40, 0.60, 1.00), 28, 130.0, 0.0)
	VFX.ring(global_position, get_parent(), Color(0.50, 0.65, 1.0, 0.90), 60.0, 0.50)

func _cast_heal() -> void:
	if not SkillManager.has("heal"): return
	if not mana.spend(HEAL_COST): return
	AudioManager.play("heal")
	hp.heal(HEAL_AMOUNT)
	VFX.burst(global_position + Vector2(0, -20), get_parent(), Color(0.30, 1.00, 0.50), 22, 95.0, 80.0)
	VFX.ring(global_position, get_parent(), Color(0.28, 1.0, 0.48, 0.80), 30.0, 0.40)
	var dmg = DamageNumber.instantiate()
	get_parent().add_child(dmg)
	dmg.position = global_position + Vector2(0, -32)
	dmg.setup(HEAL_AMOUNT, Color(0.28, 1.0, 0.48))

func _cast_magic_dash() -> void:
	if not SkillManager.has("magic_dash"): return
	if is_dashing or dash_cooldown_timer > 0.0: return
	if not mana.spend(DASH_COST): return
	AudioManager.play("dash")
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	iframe_timer = max(iframe_timer, DASH_DURATION)

func _cast_convoke() -> void:
	# CONVOKE: a Soph convoca a Juju (fada). Ela voa ~3s (vulnerável) e então
	# adormece todos os inimigos por 10s antes de sair. Só uma Juju por vez.
	if not SkillManager.has("convoke"): return
	if convoke_cd > 0.0: return
	if get_tree().get_first_node_in_group("juju"): return
	if not mana.spend(CONVOKE_COST): return
	convoke_cd = CONVOKE_CD
	_set_attack_pose("cast", 0.30)
	AudioManager.play("time_stop", 1.15)
	VFX.ring(global_position + Vector2(0, -18), get_parent(), Color(0.72, 1.0, 0.68, 0.85), 40.0, 0.45)
	VFX.sparkle(global_position + Vector2(0, -18), get_parent(), Color(0.75, 1.0, 0.62), 16)
	var juju = Juju.instantiate()
	juju.global_position = global_position + Vector2(facing * 28, -60)
	get_parent().add_child(juju)

func _cast_convoke_will() -> void:
	# CONVOKE do Will: cai do céu na frente da Soph, esmaga quem estiver lá e
	# segura a guarda com o escudo gigante. Só um Will por vez.
	if not SkillManager.has("convoke_will"): return
	if convoke_will_cd > 0.0: return
	if get_tree().get_first_node_in_group("will_shield"): return
	if not mana.spend(CONVOKE_WILL_COST): return
	convoke_will_cd = CONVOKE_WILL_CD
	_set_attack_pose("cast", 0.30)
	AudioManager.play("time_stop", 0.9)
	VFX.ring(global_position + Vector2(0, -18), get_parent(), Color(0.85, 0.78, 0.45, 0.85), 40.0, 0.45)
	var will = WillAlly.instantiate()
	will.facing = facing
	get_parent().add_child(will)
	will.global_position = global_position + Vector2(facing * 70, 0)

func _cast_convoke_gus() -> void:
	# CONVOKE do Gus: surge por trás da Soph e parte pra cima dos inimigos com as
	# duas adagas + finalização. Só um Gus por vez.
	if not SkillManager.has("convoke_gus"): return
	if convoke_gus_cd > 0.0: return
	if get_tree().get_first_node_in_group("gus"): return
	if not mana.spend(CONVOKE_GUS_COST): return
	convoke_gus_cd = CONVOKE_GUS_CD
	_set_attack_pose("cast", 0.26)
	AudioManager.play("dash", 1.0)
	VFX.sparkle(global_position + Vector2(-facing * 16, -18), get_parent(), Color(0.5, 0.9, 0.8), 12)
	var gus = GusAlly.instantiate()
	gus.facing = facing
	get_parent().add_child(gus)
	gus.global_position = global_position + Vector2(-facing * 24, 0)   # surge por trás

func _cast_convoke_di() -> void:
	# CONVOKE da Di: surge ao alto/atrás da Soph e despeja a chuva de flechas.
	# Só uma Di por vez.
	if not SkillManager.has("convoke_di"): return
	if convoke_di_cd > 0.0: return
	if get_tree().get_first_node_in_group("di"): return
	if not mana.spend(CONVOKE_DI_COST): return
	convoke_di_cd = CONVOKE_DI_CD
	_set_attack_pose("cast", 0.26)
	AudioManager.play("unlock", 1.2)
	VFX.sparkle(global_position + Vector2(-facing * 20, -56), get_parent(), Color(0.6, 1.0, 0.7), 14)
	var di = DiAlly.instantiate()
	di.facing = facing
	get_parent().add_child(di)
	di.global_position = global_position + Vector2(-facing * 30, -56)   # perch ao alto/atrás

func _cast_convoke_gui() -> void:
	# CONVOKE do Gui Fenrir: rush de espadão (espetinho/estocada) + lobisomem.
	# Só um Gui por vez.
	if not SkillManager.has("convoke_gui"): return
	if convoke_gui_cd > 0.0: return
	if get_tree().get_first_node_in_group("gui_fenrir"): return
	if not mana.spend(CONVOKE_GUI_COST): return
	convoke_gui_cd = CONVOKE_GUI_CD
	_set_attack_pose("cast", 0.26)
	AudioManager.play("dash", 0.95)
	VFX.sparkle(global_position + Vector2(-facing * 18, -18), get_parent(), Color(0.8, 0.78, 0.72), 12)
	var gui = GuiAlly.instantiate()
	gui.facing = facing
	get_parent().add_child(gui)
	gui.global_position = global_position + Vector2(-facing * 26, 0)   # surge por trás

func _cast_convoke_rose() -> void:
	# CONVOKE da mãe Rose: paira sobre a Soph e solta a Execução Aurora (gelo).
	if not SkillManager.has("convoke_rose"): return
	if convoke_rose_cd > 0.0: return
	if get_tree().get_first_node_in_group("rose"): return
	if not mana.spend(CONVOKE_ROSE_COST): return
	convoke_rose_cd = CONVOKE_ROSE_CD
	_set_attack_pose("cast", 0.3)
	AudioManager.play("unlock", 0.9)
	VFX.ring(global_position + Vector2(0, -18), get_parent(), Color(0.6, 0.95, 1.0, 0.85), 40.0, 0.45)
	var rose = RoseAlly.instantiate()
	rose.facing = facing
	get_parent().add_child(rose)
	rose.global_position = global_position + Vector2(0, -90)   # paira por cima

func _cast_convoke_ze() -> void:
	# CONVOKE do pai Zé: paira sobre a Soph e solta a Grande Bola de Fogo.
	if not SkillManager.has("convoke_ze"): return
	if convoke_ze_cd > 0.0: return
	if get_tree().get_first_node_in_group("ze"): return
	if not mana.spend(CONVOKE_ZE_COST): return
	convoke_ze_cd = CONVOKE_ZE_CD
	_set_attack_pose("cast", 0.3)
	AudioManager.play("unlock", 0.8)
	VFX.ring(global_position + Vector2(0, -18), get_parent(), Color(1.0, 0.6, 0.2, 0.85), 40.0, 0.45)
	var ze = ZeAlly.instantiate()
	ze.facing = facing
	get_parent().add_child(ze)
	ze.global_position = global_position + Vector2(0, -90)   # paira por cima

func _set_attack_pose(p: String, dur: float = 0.22) -> void:
	_attack_pose = p
	_attack_pose_timer = dur
	if p == "cast":   # brilho elemental das unhas nas mãos ao conjurar
		Nails.cast_glow(global_position + Vector2(facing * 18, -16), get_parent())

func _attack_sword() -> void:
	if sword_timer > 0.0 or is_dashing: return
	sword_timer = SWORD_COOLDOWN
	attack_flash_timer = SWORD_FLASH
	_set_attack_pose("slash", 0.20)
	AudioManager.play("sword")
	var slash = SwordSlash.instantiate()
	slash.facing = facing
	slash.global_position = global_position + Vector2(facing * 36, -16)
	get_parent().add_child(slash)
	# Peso do golpe: passo pra frente no chão + squash horizontal (compromisso).
	if is_on_floor():
		velocity.x = facing * SWORD_LUNGE
	_squash = Vector2(1.18, 0.86)

func gain_mana_from_melee() -> void:
	# Agressão recompensa: acertar com o cajado devolve mana (loop melee↔magia).
	mana.restore(MELEE_MANA_GAIN)
	AudioManager.play("orb_pickup", randf_range(1.15, 1.3))

func apply_burn(dps: float, duration: float) -> void:
	_burn_dps   = maxf(dps, _burn_dps)
	_burn_timer = maxf(duration, _burn_timer)
	_burn_tick  = 0.5
	AudioManager.play("burn", randf_range(0.85, 1.15))

func is_shielded() -> bool:
	return _shield_active

func take_damage(amount: float, source_position: Vector2 = global_position) -> void:
	if iframe_timer > 0.0 or is_dead: return
	# Guarda do Will: enquanto o escudo aguenta, absorve 100% dos hits comuns
	# (mobs/boss). O facho do boss NÃO passa por aqui — ele dana o HP do escudo
	# direto; quando o escudo estoura, este guard some e o dano volta a entrar.
	var guard := get_tree().get_first_node_in_group("will_shield")
	if guard and is_instance_valid(guard) and guard.has_method("is_guarding") and guard.is_guarding():
		guard.block_hit(amount, source_position)
		return
	if _shield_active:
		AudioManager.play("shield_hit")
		if _shield_visual:
			_shield_visual.hit_flash()
		VFX.burst(global_position + Vector2(0, -18), get_parent(), Color(0.30, 0.68, 1.0), 8, 55.0, 30.0)
		return
	hp.take_damage(amount)
	mana.bump_combat()   # levar dano mantém a regen passiva pausada (em combate)
	iframe_timer = IFRAME_DURATION
	AudioManager.play("hit_player")
	shake(7.0, 0.28)
	GameState.start_hitstop()
	_squash = Vector2(1.22, 0.80)
	var kdir = sign(global_position.x - source_position.x)
	if kdir == 0: kdir = -facing
	velocity = Vector2(kdir * KNOCKBACK_FORCE, -200.0)

func get_skill_cooldown(skill: String) -> float:
	match skill:
		"magic_dash":        return dash_cooldown_timer / DASH_COOLDOWN
		"sword":             return sword_timer / SWORD_COOLDOWN
		"magic_missile":     return magic_missile_cd / MAGIC_MISSILE_CD if magic_missile_cd > 0.0 \
									else (0.0 if mana.current_mana >= MAGIC_MISSILE_COST else 0.75)
		"missile_spread":    return missile_spread_cd / MISSILE_SPREAD_CD if missile_spread_cd > 0.0 \
									else (0.0 if mana.current_mana >= MISSILE_SPREAD_COST else 0.75)
		"missile_piercing":  return missile_piercing_cd / MISSILE_PIERCING_CD if missile_piercing_cd > 0.0 \
									else (0.0 if mana.current_mana >= MISSILE_PIERCING_COST else 0.75)
		"missile_giant":     return missile_giant_cd / MISSILE_GIANT_CD if missile_giant_cd > 0.0 \
									else (0.0 if mana.current_mana >= MISSILE_GIANT_COST else 0.75)
		"missile_curved":    return missile_curved_cd / MISSILE_CURVED_CD if missile_curved_cd > 0.0 \
									else (0.0 if mana.current_mana >= MISSILE_CURVED_COST else 0.75)
		"magic_shield":      return shield_cd_timer / MAGIC_SHIELD_CD if shield_cd_timer > 0.0 \
									else (1.0 if _shield_active else (0.0 if mana.current_mana >= MAGIC_SHIELD_COST else 0.75))
		"convoke":           return convoke_cd / CONVOKE_CD if convoke_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_COST else 0.75)
		"convoke_will":      return convoke_will_cd / CONVOKE_WILL_CD if convoke_will_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_WILL_COST else 0.75)
		"convoke_gus":       return convoke_gus_cd / CONVOKE_GUS_CD if convoke_gus_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_GUS_COST else 0.75)
		"convoke_di":        return convoke_di_cd / CONVOKE_DI_CD if convoke_di_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_DI_COST else 0.75)
		"convoke_gui":       return convoke_gui_cd / CONVOKE_GUI_CD if convoke_gui_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_GUI_COST else 0.75)
		"convoke_rose":      return convoke_rose_cd / CONVOKE_ROSE_CD if convoke_rose_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_ROSE_COST else 0.75)
		"convoke_ze":        return convoke_ze_cd / CONVOKE_ZE_CD if convoke_ze_cd > 0.0 \
									else (0.0 if mana.current_mana >= CONVOKE_ZE_COST else 0.75)
		"time_stop":         return 0.0 if mana.current_mana >= TIME_STOP_COST     else 0.75
		"heal":              return 0.0 if mana.current_mana >= HEAL_COST          else 0.75
		"double_jump":       return 0.0 if jumps_remaining > 0                     else 1.0
	return 0.0

func set_cutscene(active: bool) -> void:
	is_cutscene = active

func _spawn_dash_ghost() -> void:
	var frame_tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) \
		if sprite.sprite_frames else null
	if not frame_tex:
		return
	var ghost := Sprite2D.new()
	ghost.texture     = frame_tex
	ghost.flip_h      = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.modulate    = Color(0.35, 0.80, 1.0, 0.55)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.z_index     = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.20)
	tw.tween_callback(ghost.queue_free)

func fall_into_void() -> void:
	if is_dead: return
	is_dead = true
	velocity = Vector2.ZERO
	AudioManager.play("die")
	shake(10.0, 0.45)
	sprite.modulate = Color(0.20, 0.20, 0.45, 1.0)
	_death_fade()

func respawn() -> void:
	is_dead = false
	is_dashing = false
	is_cutscene = false
	jumps_remaining = _max_air_jumps()
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp.restore_full()
	mana.restore_full()
	iframe_timer = IFRAME_DURATION
	sprite.modulate = base_modulate
	hair.modulate   = Color.WHITE
	_squash             = Vector2.ONE
	_look_ahead         = 0.0
	_tracking_fall      = false
	_air_hiked          = false
	_was_fall_dangerous = false
	_burn_timer         = 0.0
	_burn_dps           = 0.0
	_burn_flash         = 0.0
	if _shield_visual:
		_shield_visual.deactivate()
	_shield_active  = false
	shield_timer    = 0.0

func _update_visuals() -> void:
	var sq := _squash
	if is_on_floor() and abs(velocity.x) < 5.0 and not is_dashing and not is_dead \
			and sq.distance_squared_to(Vector2.ONE) < 0.0004:
		var breathe := 1.0 + 0.018 * sin(Time.get_ticks_msec() * 0.001 * TAU * 0.40)
		sq = Vector2(breathe, breathe)

	# ── Dinamismo de movimento (AAA): stretch por velocidade + lean (skew) ──────
	var sr := clampf(absf(velocity.x) / SPEED, 0.0, 1.3)
	if not is_on_floor():
		var ar := clampf(absf(velocity.y) / 640.0, 0.0, 1.0)   # esticar no ar (sobe/cai rápido)
		sq.y *= 1.0 + ar * 0.14
		sq.x *= 1.0 - ar * 0.08
	elif sr > 0.05:
		sq.x *= 1.0 + sr * 0.06                                 # esticar correndo
		sq.y *= 1.0 - sr * 0.04
	# Inclinação na direção do movimento (corpo/cabelo "se jogam" pra frente)
	var tgt_lean := clampf(velocity.x / SPEED, -1.2, 1.2) * 0.13
	if not is_on_floor():
		tgt_lean *= 0.5
	elif sr < 0.06:
		tgt_lean = 0.022 * sin(Time.get_ticks_msec() * 0.001 * TAU * 0.33)   # idle vivo (sway sutil)
	if is_dashing:
		tgt_lean = facing * 0.30
	_lean = lerpf(_lean, tgt_lean, 0.30)
	# "Pop" elástico ao trocar de direção no chão
	if is_on_floor() and signf(facing) != signf(_last_facing):
		_squash = Vector2(0.82, 1.20)
	_last_facing = facing

	# Animation state ANTES da escala/flip pra sabermos qual anim usar
	# na compensação per-anim do HD.
	_update_anim()

	var anim_scale := 1.0
	var anim_flip_left := false
	if USE_HD_SOPH:
		var ab := _hd_anim_base()
		var bbox: float = HD_ANIM_BBOX.get(ab, HD_BASE_BBOX)
		anim_scale = HD_BASE_BBOX / bbox
		# Mantém os pés no mesmo Y na tela ao reduzir a escala da anim
		# (sem isto, escalas menores deixam a Soph "flutuando" um pouco).
		var target_feet := HD_OFFSET.y + (HD_FRAME_H * 0.5) * HD_SCALE
		var feet_now := (HD_FRAME_H * 0.5) * (HD_SCALE * anim_scale)
		sprite.position = Vector2(HD_OFFSET.x, target_feet - feet_now)
		anim_flip_left = HD_ANIM_NATIVE_LEFT.get(ab, false)

	sprite.scale = _base_scale * sq * anim_scale
	hair.scale   = sq
	sprite.skew  = _lean
	hair.skew    = _lean

	# Flip to face direction (HD: XOR com a orientação nativa da anim).
	var flip := facing < 0
	if anim_flip_left:
		flip = not flip
	sprite.flip_h = flip
	hair.flip_h   = flip

	if is_dashing:
		sprite.modulate = Color(0.5, 0.85, 1.0, 1.0)
		return
	if attack_flash_timer > 0.0:
		sprite.modulate = Color(1.6, 1.6, 1.0, 1.0)
		return
	if _burn_flash > 0.0:
		sprite.modulate = Color(1.6, 0.55, 0.20, 1.0)
		return
	var c := base_modulate
	if iframe_timer > 0.0:
		c.a = 0.4 if fmod(iframe_timer, 0.15) > 0.075 else 1.0
	# Mana dim: non-baked anims fade toward a desaturated dark tint as mana drains.
	# Idle/cast/slash usam arte por nível com cabelo já bakeado — pula pra evitar
	# escurecimento duplo.
	var a := sprite.animation
	var baked := a.begins_with("idle_") or a.begins_with("cast_") or a.begins_with("slash_")
	if not baked:
		var target := Color(c.r * 0.55, c.g * 0.55, c.b * 0.70, c.a)
		c = c.lerp(target, 1.0 - _mana_ratio)
	sprite.modulate = c

func _hd_anim_base() -> String:
	# "cast_3"/"idle_5" → "cast"/"idle"; "walk"/"run"/"jump" → mesmo nome.
	var a := sprite.animation
	var us := a.find("_")
	return a.substr(0, us) if us >= 0 else a

func _update_anim() -> void:
	var spd := absf(velocity.x)
	var anim: String
	if _attack_pose_timer > 0.0:
		# Cajado/lâmina exposto durante o ataque. Cada pose tem 5 variantes (1..5)
		# c/ cabelo escurecido pelo nível de mana atual.
		anim = "%s_%d" % [_attack_pose, _mana_level]
	elif not is_on_floor():
		anim = "fall" if velocity.y > 80.0 else "jump"
	elif iframe_timer > 0.7:
		anim = "hurt"
	elif spd > 180.0:
		anim = "run"
	elif spd > 20.0:
		anim = "walk"
	else:
		anim = "idle_%d" % _mana_level
	if sprite.animation != anim:
		sprite.play(anim)

func _build_soph_frames() -> SpriteFrames:
	if USE_HD_SOPH:
		return _build_soph_frames_hd()
	return _build_soph_frames_pixel()

func _build_soph_frames_pixel() -> SpriteFrames:
	var sf := SpriteFrames.new()
	# idle: 2 frames, 4 fps (slow breathe)
	_add_anim(sf, "idle",  ["soph_idle_0", "soph_idle_1"], 4.0,  true)
	# walk: 6 frames, 10 fps
	_add_anim(sf, "walk",  ["soph_walk_0","soph_walk_1","soph_walk_2",
							  "soph_walk_3","soph_walk_4","soph_walk_5"], 10.0, true)
	# run: 6 frames, 16 fps (corrida fluida AAA)
	_add_anim(sf, "run",   ["soph_run_0","soph_run_1","soph_run_2",
							  "soph_run_3","soph_run_4","soph_run_5"], 16.0, true)
	# jump/fall: 2 frames cada (lançamento↔ápice e queda esvoaçante)
	_add_anim(sf, "jump",  ["soph_jump_0", "soph_jump_1"], 6.0, false)
	_add_anim(sf, "fall",  ["soph_fall_0", "soph_fall_1"], 5.0, true)
	_add_anim(sf, "hurt",  ["soph_hurt"],  8.0, false)
	# Poses de ataque por nível de mana: cada uma com 2 frames (windup → release/impacto).
	# O cabelo já vem bakeado com o degrade de mana correto pra cada nível.
	for lvl in range(1, 6):
		_add_anim(sf, "cast_%d"  % lvl,
				["soph_cast_%d_0"  % lvl, "soph_cast_%d_1"  % lvl], 12.0, false)
		_add_anim(sf, "slash_%d" % lvl,
				["soph_slash_%d_0" % lvl, "soph_slash_%d_1" % lvl], 14.0, false)
	# mana-state idles (level 5 = full, level 1 = depleted)
	for lvl in range(1, 6):
		_add_anim(sf, "idle_%d" % lvl, ["soph_mana_%d" % lvl], 4.0, true)
	return sf

func _build_soph_frames_hd() -> SpriteFrames:
	# Conjunto HD (soph_hd_*): idle/walk/run + jump/fall/hurt.
	var sf := SpriteFrames.new()
	_add_anim(sf, "idle", ["soph_hd_idle_0", "soph_hd_idle_1"], 3.0, true)
	# walk/run HD staff-free (set walkrun9 ancorado na master v2): maos vazias,
	# principio "arma so na acao". walk=4 frames, run=2.
	_add_anim(sf, "walk", ["soph_hd_walk_0","soph_hd_walk_1",
							 "soph_hd_walk_2","soph_hd_walk_3"], 10.0, true)
	_add_anim(sf, "run",  ["soph_hd_run_0","soph_hd_run_1"], 14.0, true)
	_add_anim(sf, "jump", ["soph_hd_jump_0"], 8.0, false)
	_add_anim(sf, "fall", ["soph_hd_fall_0"], 8.0, false)
	_add_anim(sf, "hurt", ["soph_hd_hurt_0"], 8.0, false)
	# Poses de ataque HD do set1 (cast = magia com a gema; slash = golpe com o cajado).
	# Mesmos frames pra todo nível de mana por ora — variantes de cabelo virão da
	# recoloração procedural por máscara (ver CLAUDE.md: mana no cabelo).
	for lvl in range(1, 6):
		_add_anim(sf, "cast_%d"  % lvl, ["soph_hd_cast_0", "soph_hd_cast_1"], 12.0, false)
		_add_anim(sf, "slash_%d" % lvl, ["soph_hd_slash_0", "soph_hd_slash_1"], 14.0, false)
	# Estados de mana no idle reusam a arte HD (sem escurecer o cabelo por ora).
	for lvl in range(1, 6):
		_add_anim(sf, "idle_%d" % lvl, ["soph_hd_idle_0", "soph_hd_idle_1"], 3.0, true)
	return sf

func _add_anim(sf: SpriteFrames, name: String, keys: Array, fps: float, loop: bool) -> void:
	if sf.has_animation(name):
		sf.remove_animation(name)
	sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	var base_dir := "res://assets/sprites/player/"
	for key in keys:
		var path: String = base_dir + key + ".png"
		var tex: Texture2D
		if ResourceLoader.exists(path):
			tex = ResourceLoader.load(path) as Texture2D
		if not tex:
			# Fallback: load via FileAccess
			var img := Image.new()
			if FileAccess.file_exists(path) and img.load(path) == OK:
				tex = ImageTexture.create_from_image(img)
		if not tex:
			# Ultimate fallback: use procedural body texture as a static stand-in
			tex = SpriteSetup.get_texture("player_body")
		if tex:
			sf.add_frame(name, tex)

func _on_mana_changed(ratio: float) -> void:
	_mana_ratio = ratio
	_mana_level = clampi(ceili(ratio * 5.0), 1, 5)
	# Mid-anim swap: se já está em uma anim com cabelo bakeado por nível
	# (idle/cast/slash), troca pro nível atual sem reiniciar o frame.
	var a := sprite.animation
	for base in ["idle", "cast", "slash"]:
		if a.begins_with(base + "_"):
			var f := sprite.frame
			sprite.play("%s_%d" % [base, _mana_level])
			sprite.frame = f
			return

func _on_died() -> void:
	is_dead = true
	if is_aiming:
		_end_aim()        # garante restaurar o tempo se morrer mirando
	AudioManager.play("die")
	shake(12.0, 0.5)
	sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	_death_fade()

func _death_fade() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	get_tree().root.add_child(cl)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(overlay)
	var death_lines := [
		"Você caiu...",
		"Ainda não era sua hora...",
		"O Fireball ainda espera...",
		"Tente novamente...",
		"A magia não erra duas vezes...",
	]
	var msg := Label.new()
	msg.text = death_lines[randi() % death_lines.size()]
	msg.anchor_left = 0.0; msg.anchor_right = 1.0
	msg.anchor_top = 0.43; msg.anchor_bottom = 0.57
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 30)
	msg.add_theme_color_override("font_color", Color(0.85, 0.18, 0.18))
	msg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	msg.add_theme_constant_override("shadow_offset_x", 2)
	msg.add_theme_constant_override("shadow_offset_y", 2)
	msg.modulate.a = 0.0
	cl.add_child(msg)
	var sub := Label.new()
	sub.text = "— Soph"
	sub.anchor_left = 0.0; sub.anchor_right = 1.0
	sub.anchor_top = 0.54; sub.anchor_bottom = 0.64
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.60, 0.50, 0.65, 0.85))
	sub.modulate.a = 0.0
	cl.add_child(sub)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.45)
	tw.tween_property(msg, "modulate:a", 1.0, 0.30)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.40).set_delay(0.15)
	tw.tween_interval(0.55)
	tw.tween_property(msg, "modulate:a", 0.0, 0.20)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.20)
	tw.tween_callback(respawn)
	tw.tween_property(overlay, "color:a", 0.0, 0.55)
	tw.tween_callback(cl.queue_free)

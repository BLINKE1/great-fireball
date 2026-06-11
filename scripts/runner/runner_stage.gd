extends Node2D
## Estágios do run-and-gun (homenagem ORIGINAL ao gênero). Monta o nível
## procedural (linhas/blocos roxos + fundo preto), spawna a Soph e inimigos,
## cuida de vidas/respawn/checkpoint e invoca o boss. Layouts AUTORAIS, feitos
## pra serem corríveis (começo aberto, buracos saltáveis, sem parede travando).

const Hero  := preload("res://scripts/runner/runner_hero.gd")
const Enemy := preload("res://scripts/runner/runner_enemy.gd")
const Boss  := preload("res://scripts/runner/runner_boss.gd")

const FLOOR_Y := 440.0
const PURPLE := Color(0.62, 0.25, 0.95)
const PURPLE_TOP := Color(0.85, 0.45, 1.0)
const FILL := Color(0.12, 0.05, 0.22)

static var boot_stage: int = 1

var stage_num: int = 1
var hero: CharacterBody2D
var lives: int = 3
var checkpoint_pos: Vector2 = Vector2(90, FLOOR_Y)
var boss_spawned: bool = false
var boss: Node = null
var won: bool = false
var dead: bool = false

var ground_segs: Array = []            # [[x0,x1], ...] p/ validação de travessia
var boss_trigger_x: float = 2300.0
var boss_spawn: Vector2 = Vector2(2650, FLOOR_Y - 130)
var boss_hp: int = 24
var _cp_x: float = -1.0

var _lives_lbl: Label
var _pw_lbl: Label
var _msg_lbl: Label
var _boss_bar: ColorRect
var _boss_bar_bg: ColorRect
var _stars: Node2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	stage_num = boot_stage
	_build_starfield()
	if stage_num == 2:
		_build_stage2()
	else:
		_build_stage1()
	hero = Hero.new()
	add_child(hero)
	hero.global_position = checkpoint_pos
	_build_hud()

# ── Níveis ────────────────────────────────────────────────────────────────────
func _build_stage1() -> void:
	_ground(0, 1250)                 # começo LONGO e aberto (corre e atira)
	_ground(1340, 2150)              # buraco saltável 1250..1340
	_ground(2150, 3050)              # arena do boss (contínua)
	_plat(650, 330, 150, 16)
	_plat(950, 280, 150, 16)
	_plat(1500, 330, 150, 16)
	_plat(1850, 290, 140, 16)
	_wall(3030, FLOOR_Y - 250, 250)  # parede só no FIM (não trava o caminho)
	_enemy("walker", 380, FLOOR_Y, "spread")
	_enemy("flyer", 620, 320, "")
	_enemy("hopper", 900, FLOOR_Y, "speed")
	_enemy("flyer", 1150, 300, "rapid")
	_enemy("walker", 1500, FLOOR_Y, "")
	_enemy("flyer", 1780, 300, "")
	_enemy("hopper", 1980, FLOOR_Y, "")
	_enemy("walker", 2350, FLOOR_Y, "")
	_checkpoint_flag(1340)
	boss_trigger_x = 2350.0
	boss_spawn = Vector2(2680, FLOOR_Y - 130)
	boss_hp = 24

func _build_stage2() -> void:
	_ground(0, 900)
	_ground(990, 1750)               # buraco 900..990
	_ground(1840, 3050)              # buraco 1750..1840 ; arena
	_plat(500, 350, 140, 16)
	_plat(760, 300, 130, 16)
	_plat(1100, 330, 150, 16)
	_plat(1320, 270, 140, 16)
	_plat(1560, 350, 140, 16)
	_plat(2050, 320, 150, 16)
	_wall(3030, FLOOR_Y - 250, 250)
	_enemy("turret", 460, FLOOR_Y, "rapid")
	_enemy("flyer", 680, 300, "spread")
	_enemy("turret", 1160, 330, "")          # em cima da plataforma
	_enemy("walker", 1050, FLOOR_Y, "")
	_enemy("flyer", 1350, 260, "")
	_enemy("hopper", 1560, FLOOR_Y, "speed")
	_enemy("turret", 1980, FLOOR_Y, "")
	_enemy("flyer", 2180, 300, "")
	_enemy("walker", 2420, FLOOR_Y, "")
	_checkpoint_flag(1840)
	boss_trigger_x = 2300.0
	boss_spawn = Vector2(2680, FLOOR_Y - 130)
	boss_hp = 32

# ── Construtores de cenário ───────────────────────────────────────────────────
func _ground(x0: float, x1: float) -> void:
	ground_segs.append([x0, x1])
	_plat(x0, FLOOR_Y, x1 - x0, 110)

func _wall(x: float, y: float, h: float) -> void:
	_plat(x, y, 20, h)

func _plat(x: float, y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	body.add_child(cs)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2),
		Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2)])
	poly.color = FILL
	body.add_child(poly)
	var gx := -w / 2.0 + 40.0          # grade interna fraca
	while gx < w / 2.0:
		var tick := Line2D.new()
		tick.width = 1.0
		tick.default_color = Color(0.5, 0.2, 0.8, 0.22)
		tick.points = PackedVector2Array([Vector2(gx, -h / 2), Vector2(gx, h / 2)])
		body.add_child(tick)
		gx += 40.0
	var border := Line2D.new()
	border.width = 2.0
	border.default_color = PURPLE
	border.points = PackedVector2Array([
		Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2),
		Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2), Vector2(-w / 2, -h / 2)])
	body.add_child(border)
	var top := Line2D.new()
	top.width = 3.0
	top.default_color = PURPLE_TOP
	top.points = PackedVector2Array([Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2)])
	body.add_child(top)
	add_child(body)

func _enemy(kind: String, x: float, y: float, drop: String) -> void:
	var e := Enemy.new()
	e.kind = kind
	e.drops_power = drop
	add_child(e)
	e.global_position = Vector2(x, y)

func _checkpoint_flag(x: float) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(0.5, 1.0, 0.7, 0.7)
	l.points = PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x, FLOOR_Y - 64)])
	add_child(l)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(x, FLOOR_Y - 64), Vector2(x + 20, FLOOR_Y - 56), Vector2(x, FLOOR_Y - 48)])
	flag.color = Color(0.4, 1.0, 0.6, 0.7)
	add_child(flag)
	_cp_x = x

func _build_starfield() -> void:
	# Pontos roxos estáticos (sem parallax) só pra a tela preta não ficar vazia.
	_stars = Node2D.new()
	add_child(_stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(90):
		var s := Polygon2D.new()
		var px := rng.randf_range(-200, 3200)
		var py := rng.randf_range(-120, 360)
		var r := rng.randf_range(0.8, 1.8)
		s.polygon = PackedVector2Array([Vector2(px - r, py), Vector2(px, py - r), Vector2(px + r, py), Vector2(px, py + r)])
		s.color = Color(0.5, 0.3, 0.8, rng.randf_range(0.15, 0.5))
		_stars.add_child(s)

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_lives_lbl = Label.new()
	_lives_lbl.position = Vector2(10, 8)
	_lives_lbl.add_theme_font_size_override("font_size", 14)
	cl.add_child(_lives_lbl)
	_pw_lbl = Label.new()
	_pw_lbl.position = Vector2(10, 26)
	_pw_lbl.add_theme_font_size_override("font_size", 10)
	_pw_lbl.modulate = Color(0.85, 0.9, 1.0)
	cl.add_child(_pw_lbl)
	_boss_bar_bg = ColorRect.new()
	_boss_bar_bg.color = Color(0.2, 0.05, 0.05, 0.8)
	_boss_bar_bg.position = Vector2(160, 12)
	_boss_bar_bg.size = Vector2(300, 10)
	_boss_bar_bg.visible = false
	cl.add_child(_boss_bar_bg)
	_boss_bar = ColorRect.new()
	_boss_bar.color = Color(0.85, 0.4, 1.0)
	_boss_bar.position = Vector2(161, 13)
	_boss_bar.size = Vector2(298, 8)
	_boss_bar.visible = false
	cl.add_child(_boss_bar)
	_msg_lbl = Label.new()
	_msg_lbl.position = Vector2(150, 150)
	_msg_lbl.add_theme_font_size_override("font_size", 26)
	cl.add_child(_msg_lbl)
	_update_hud()

func _update_hud() -> void:
	_lives_lbl.text = "VIDAS: %d   ESTÁGIO %d" % [max(lives, 0), stage_num]
	var pw := []
	if hero and is_instance_valid(hero):
		if hero.pw_spread: pw.append("TRIPLO")
		if hero.pw_rapid:  pw.append("RÁPIDO")
		if hero.pw_speed:  pw.append("VELOZ")
	_pw_lbl.text = "  ".join(pw)

# ── Loop ──────────────────────────────────────────────────────────────────────
func _process(_d: float) -> void:
	if not hero or not is_instance_valid(hero):
		return
	if _cp_x > 0.0 and checkpoint_pos.x < _cp_x and hero.global_position.x > _cp_x:
		checkpoint_pos = Vector2(_cp_x, FLOOR_Y)
	if not boss_spawned and hero.global_position.x > boss_trigger_x:
		_spawn_boss()
	if boss and is_instance_valid(boss):
		_boss_bar.size.x = 298.0 * (float(boss.hp) / float(boss.max_hp))
	_update_hud()

func _spawn_boss() -> void:
	boss_spawned = true
	boss = Boss.new()
	boss.pattern = stage_num
	boss.max_hp = boss_hp
	boss.hp = boss_hp
	add_child(boss)
	boss.global_position = boss_spawn
	boss.defeated.connect(_on_boss_defeated)
	_boss_bar_bg.visible = true
	_boss_bar.visible = true
	AudioManager.play("boss_appear")

func _on_boss_defeated() -> void:
	won = true
	_boss_bar_bg.visible = false
	_boss_bar.visible = false
	_msg_lbl.modulate = Color(0.7, 1.0, 0.7)
	if stage_num == 1:
		_msg_lbl.text = "ESTÁGIO 1 CONCLUÍDO!  →  ESTÁGIO 2"
		await get_tree().create_timer(2.4).timeout
		boot_stage = 2
		if get_tree().current_scene == self:
			get_tree().reload_current_scene()
	else:
		_msg_lbl.text = "VOCÊ VENCEU!  (estágios 1–2)"

# ── Chamado pelo herói ────────────────────────────────────────────────────────
func hero_died() -> void:
	lives -= 1
	_update_hud()
	if lives < 0:
		dead = true
		_msg_lbl.text = "FIM DE JOGO"
		_msg_lbl.modulate = Color(1.0, 0.5, 0.5)
		return
	hero.respawn(checkpoint_pos)

func spawn_powerup(pos: Vector2, kind: String) -> void:
	var col := Color(0.7, 0.4, 1.0)
	match kind:
		"rapid": col = Color(1.0, 0.9, 0.3)
		"speed": col = Color(0.3, 0.95, 1.0)
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for yy in range(14):
		for xx in range(14):
			if absi(xx - 7) + absi(yy - 7) <= 6:
				img.set_pixel(xx, yy, col)
			elif absi(xx - 7) + absi(yy - 7) == 7:
				img.set_pixel(xx, yy, Color(1, 1, 1, 0.9))
	var p := Sprite2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.scale = Vector2(2, 2)
	p.set_meta("kind", kind)
	p.add_to_group("rpower")
	add_child(p)
	p.global_position = pos

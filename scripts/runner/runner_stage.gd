extends Node2D
## Estágio 1 do run-and-gun (homenagem original). Monta o nível procedural
## (linhas roxas / fundo preto), spawna a Soph e inimigos, cuida de vidas/respawn/
## checkpoint e invoca o boss no fim. Layout AUTORAL (inspirado no gênero).

const Hero  := preload("res://scripts/runner/runner_hero.gd")
const Enemy := preload("res://scripts/runner/runner_enemy.gd")
const Boss  := preload("res://scripts/runner/runner_boss.gd")

const FLOOR_Y := 440.0
const PURPLE := Color(0.62, 0.25, 0.95)
const PURPLE_DIM := Color(0.40, 0.16, 0.66)
const BOSS_TRIGGER_X := 2150.0

var hero: CharacterBody2D
var lives: int = 3
var checkpoint_pos: Vector2 = Vector2(90, FLOOR_Y)
var boss_spawned: bool = false
var boss: Node = null
var won: bool = false
var dead: bool = false

var _lives_lbl: Label
var _pw_lbl: Label
var _msg_lbl: Label
var _boss_bar: ColorRect
var _boss_bar_bg: ColorRect

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_level()
	hero = Hero.new()
	add_child(hero)
	hero.global_position = checkpoint_pos
	_build_hud()

# ── Nível ─────────────────────────────────────────────────────────────────────
func _build_level() -> void:
	# Chãos (gaps no meio, plataforma de apoio no buraco)
	_ground(0, 920)
	_plat(925, 395, 90, 16)          # degrau no buraco
	_ground(1010, 1900)
	_ground(2000, 2900)              # arena do boss
	# Plataformas flutuantes
	_plat(480, 360, 130, 18)
	_plat(740, 290, 130, 18)
	_plat(1300, 360, 150, 18)
	# Paredes da arena
	_plat(1980, 200, 20, 260)
	_plat(2880, 200, 20, 260)
	# Inimigos (kind, x, y, drop)
	_enemy("walker", 320, FLOOR_Y, "spread")
	_enemy("flyer", 560, 320, "")
	_enemy("hopper", 800, 280, "speed")
	_enemy("flyer", 1150, 350, "rapid")
	_enemy("walker", 1450, FLOOR_Y, "")
	_enemy("hopper", 1700, FLOOR_Y, "")
	_enemy("flyer", 1880, 330, "")
	_enemy("walker", 2300, FLOOR_Y, "")
	# Marcador de checkpoint (visual)
	_checkpoint_flag(1150)

func _ground(x0: float, x1: float) -> void:
	_plat(x0, FLOOR_Y, x1 - x0, 90)

func _plat(x: float, y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	body.add_child(cs)
	var line := Line2D.new()       # contorno roxo (wireframe)
	line.width = 2.0
	line.default_color = PURPLE
	line.points = PackedVector2Array([
		Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2),
		Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2), Vector2(-w / 2, -h / 2)])
	body.add_child(line)
	var top := Line2D.new()        # topo destacado
	top.width = 3.0
	top.default_color = Color(0.8, 0.45, 1.0)
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
	l.points = PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x, FLOOR_Y - 60)])
	add_child(l)

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
	_msg_lbl.position = Vector2(180, 150)
	_msg_lbl.add_theme_font_size_override("font_size", 30)
	cl.add_child(_msg_lbl)
	_update_hud()

func _update_hud() -> void:
	_lives_lbl.text = "VIDAS: %d" % max(lives, 0)
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
	if hero.global_position.x > 1150.0 and checkpoint_pos.x < 1150.0:
		checkpoint_pos = Vector2(1150, FLOOR_Y)
	if not boss_spawned and hero.global_position.x > BOSS_TRIGGER_X:
		_spawn_boss()
	if boss and is_instance_valid(boss):
		_boss_bar.size.x = 298.0 * (float(boss.hp) / float(boss.max_hp))
	_update_hud()

func _spawn_boss() -> void:
	boss_spawned = true
	boss = Boss.new()
	add_child(boss)
	boss.global_position = Vector2(2520, FLOOR_Y - 130)
	boss.defeated.connect(_on_boss_defeated)
	_boss_bar_bg.visible = true
	_boss_bar.visible = true
	AudioManager.play("boss_appear")

func _on_boss_defeated() -> void:
	won = true
	_boss_bar_bg.visible = false
	_boss_bar.visible = false
	_msg_lbl.text = "ESTÁGIO 1 CONCLUÍDO!"
	_msg_lbl.modulate = Color(0.7, 1.0, 0.7)

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
	for y in range(14):
		for x in range(14):
			if absi(x - 7) + absi(y - 7) <= 6:        # losango
				img.set_pixel(x, y, col)
			elif absi(x - 7) + absi(y - 7) == 7:
				img.set_pixel(x, y, Color(1, 1, 1, 0.9))
	var p := Sprite2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.scale = Vector2(2, 2)
	p.set_meta("kind", kind)
	p.add_to_group("rpower")
	add_child(p)
	p.global_position = pos

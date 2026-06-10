extends Node
## Nails — sistema de UNHAS PODEROSAS (item de build da Soph).
## A maga conjura com as mãos, então as unhas são o foco mágico: cada conjunto
## (nail set) dá uma AFINIDADE ELEMENTAL que modifica o COMPORTAMENTO das magias
## (não só números). Inspirado nas "unhas impossíveis" (lava, raios, gelo...).
##
## Cross-promo: cada design real (TikTok) pode virar um nail set aqui; a arte
## detalhada vive no ÍCONE (nail_<set>) e o efeito aparece in-game nas mãos/magias.
##
## Integração: as magias chamam Nails.on_hit(enemy, pos) ao acertar, pintam o
## projétil com Nails.tint() e disparam Nails.cast_glow(pos, parent) ao conjurar.
## Tudo via os métodos públicos dos inimigos (take_damage / hp / sleep) — sem
## precisar editar cada inimigo.

signal nail_changed(set_id: String)

const ORDER := ["none", "lava", "raios", "gelo", "aurora"]

const SETS := {
	"none":   {"name": "Sem esmalte",      "color": Color(1, 1, 1),            "desc": "Sem afinidade elemental."},
	"lava":   {"name": "Unhas de Lava",    "color": Color(1.0, 0.45, 0.12),    "desc": "As magias incendeiam: dano contínuo de queimadura."},
	"raios":  {"name": "Unhas de Raios",   "color": Color(0.70, 0.90, 1.0),    "desc": "As magias saltam pra um inimigo próximo (corrente elétrica)."},
	"gelo":   {"name": "Unhas de Gelo",    "color": Color(0.65, 0.92, 1.0),    "desc": "Chance de congelar o inimigo por um instante."},
	"aurora": {"name": "Unhas Aurora",     "color": Color(0.80, 0.70, 1.0),    "desc": "Unhas impossíveis: a cada acerto, um elemento aleatório."},
}

# Lava
const BURN_DPS := 8.0
const BURN_TICKS := 4
# Raios
const CHAIN_RANGE := 130.0
const CHAIN_DMG := 14.0
# Gelo
const FREEZE_CHANCE := 0.30
const FREEZE_TIME := 0.8

const NailBurn := preload("res://scripts/spells/nail_burn.gd")

var equipped: String = "none"

func equip(set_id: String) -> void:
	if not SETS.has(set_id):
		return
	equipped = set_id
	nail_changed.emit(set_id)

func cycle() -> String:
	var i := ORDER.find(equipped)
	equipped = ORDER[(i + 1) % ORDER.size()]
	nail_changed.emit(equipped)
	return equipped

func display_name(set_id: String = "") -> String:
	var s := set_id if set_id != "" else equipped
	return SETS.get(s, SETS["none"])["name"]

func tint() -> Color:
	if equipped == "aurora":
		# arco-íris pulsante (unhas impossíveis)
		var h := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		return Color.from_hsv(h, 0.55, 1.0)
	return SETS.get(equipped, SETS["none"])["color"]

## Disparado quando uma magia da Soph ACERTA um inimigo.
func on_hit(enemy: Node, pos: Vector2) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	match equipped:
		"lava":   _burn(enemy, pos)
		"raios":  _chain(enemy, pos)
		"gelo":   _freeze(enemy, pos)
		"aurora": _aurora(enemy, pos)
		_:        pass

## Brilho elemental nas mãos da Soph ao conjurar.
func cast_glow(pos: Vector2, parent: Node) -> void:
	if equipped == "none" or parent == null or not is_instance_valid(parent):
		return
	var c := tint()
	VFX.sparkle(pos, parent, c, 5)
	if equipped == "lava":
		VFX.burst(pos, parent, Color(1.0, 0.55, 0.12), 3, 26.0, 14.0)

# ── Efeitos por elemento ──────────────────────────────────────────────────────
func _burn(enemy: Node, _pos: Vector2) -> void:
	if not _can_take(enemy):
		return
	# Refresca se já estiver pegando fogo (não empilha infinito).
	for c in enemy.get_children():
		if c.is_in_group("nail_burn"):
			c.refresh()
			return
	var b := NailBurn.new()
	b.dps = BURN_DPS
	b.ticks = BURN_TICKS
	enemy.add_child(b)

func _chain(enemy: Node, pos: Vector2) -> void:
	var nearest: Node = null
	var best := CHAIN_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == enemy or not is_instance_valid(e) or e.is_dead:
			continue
		var d: float = pos.distance_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	if nearest == null:
		return
	_lightning(pos, nearest.global_position + Vector2(0, -10), enemy)
	if _can_take(nearest):
		nearest.take_damage(CHAIN_DMG, pos)

func _freeze(enemy: Node, pos: Vector2) -> void:
	VFX.sparkle(pos, _world(enemy), Color(0.7, 0.95, 1.0), 4)
	if randf() < FREEZE_CHANCE and enemy.has_method("sleep") and not enemy.is_dead:
		enemy.sleep(FREEZE_TIME)
		VFX.ring(enemy.global_position + Vector2(0, -10), _world(enemy), Color(0.7, 0.95, 1.0, 0.8), 24.0, 0.3)

func _aurora(enemy: Node, pos: Vector2) -> void:
	match randi() % 3:
		0: _burn(enemy, pos)
		1: _chain(enemy, pos)
		_: _freeze(enemy, pos)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _can_take(e: Node) -> bool:
	return is_instance_valid(e) and not e.is_dead and e.has_method("take_damage")

func _world(e: Node) -> Node:
	# Pai onde soltar VFX (o nível); cai pro próprio inimigo se preciso.
	var p := e.get_parent()
	return p if p != null else e

func _lightning(a: Vector2, b: Vector2, ref: Node) -> void:
	var parent := _world(ref)
	if parent == null:
		return
	var ln := Line2D.new()
	ln.width = 3.0
	ln.default_color = Color(0.75, 0.95, 1.0, 0.95)
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	# zig-zag entre os dois pontos
	var pts := PackedVector2Array()
	var steps := 5
	for i in range(steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		if i != 0 and i != steps:
			var n := (b - a).orthogonal().normalized()
			p += n * randf_range(-8.0, 8.0)
		pts.append(p)
	ln.points = pts
	parent.add_child(ln)
	VFX.burst(b, parent, Color(0.8, 0.95, 1.0), 6, 60.0, 16.0)
	var tw := ln.create_tween()
	tw.tween_property(ln, "modulate:a", 0.0, 0.18)
	tw.tween_callback(ln.queue_free)

extends Node2D

# Folhas caindo da copa: derivam pra baixo com serpenteio lateral e giro.
# Respawnam logo ACIMA da linha d'agua (nao somem atras do lago). Floresta only.
# Adicionado por level_visuals.

var area_width: float = 5200.0
var count: int = 34
var top_y: float = 150.0      # onde nascem (copa)
var bottom_y: float = 476.0   # onde respawnam (logo acima da agua ~488)

var _leaves: Array = []
var _t := 0.0

const COLORS := [
	Color(0.28, 0.44, 0.20),   # verde-musgo
	Color(0.46, 0.52, 0.24),   # oliva
	Color(0.58, 0.40, 0.16),   # ambar
	Color(0.34, 0.50, 0.28),   # verde claro
]
# folha unitaria (pontuda), desenhada com transform por instancia
var LEAF := PackedVector2Array([
	Vector2(0, -1.0), Vector2(0.42, -0.25), Vector2(0.30, 0.55),
	Vector2(0, 1.0), Vector2(-0.30, 0.55), Vector2(-0.42, -0.25),
])

func _ready() -> void:
	for i in count:
		_leaves.append(_make(true))

func _make(random_y: bool) -> Dictionary:
	return {
		"x": randf() * area_width,
		"y": randf_range(top_y, bottom_y) if random_y else top_y - randf() * 80.0,
		"vx": randf_range(-10.0, 10.0),
		"vy": randf_range(16.0, 34.0),
		"rot": randf() * TAU,
		"vrot": randf_range(-1.6, 1.6),
		"sway": randf_range(10.0, 26.0),
		"phase": randf() * TAU,
		"size": randf_range(4.0, 8.0),
		"color": COLORS[randi() % COLORS.size()],
		"alpha": randf_range(0.55, 0.9),
	}

func _process(delta: float) -> void:
	_t += delta
	for lf in _leaves:
		lf.x += (lf.vx + sin(_t * 1.1 + lf.phase) * lf.sway) * delta
		lf.y += lf.vy * delta
		lf.rot += lf.vrot * delta
		if lf.y > bottom_y or lf.x < -80.0 or lf.x > area_width + 80.0:
			var n := _make(false)
			for k in n:
				lf[k] = n[k]
	queue_redraw()

func _draw() -> void:
	for lf in _leaves:
		draw_set_transform(Vector2(lf.x, lf.y), lf.rot, Vector2(lf.size, lf.size))
		var c: Color = lf.color
		c.a = lf.alpha
		draw_colored_polygon(LEAF, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

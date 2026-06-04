extends Node2D

# Partículas ambiente. Caverna: poeira fria flutuando. Floresta: vaga-lumes
# quentes que piscam (twinkle) e flutuam preguiçosos. Adicionado por level_visuals.

var area_width: float  = 5200.0
var area_height: float = 580.0
var particle_count: int = 40
var forest := false

var _px: PackedFloat32Array
var _py: PackedFloat32Array
var _vx: PackedFloat32Array
var _vy: PackedFloat32Array
var _alpha: PackedFloat32Array
var _size: PackedFloat32Array
var _phase: PackedFloat32Array
var _t := 0.0

func _ready() -> void:
	if forest:
		particle_count = int(particle_count * 1.4)   # mais vaga-lumes
	for arr in [_px, _py, _vx, _vy, _alpha, _size, _phase]:
		pass
	_px.resize(particle_count); _py.resize(particle_count)
	_vx.resize(particle_count); _vy.resize(particle_count)
	_alpha.resize(particle_count); _size.resize(particle_count)
	_phase.resize(particle_count)
	for i in particle_count:
		_init_particle(i, true)

func _init_particle(i: int, random_y: bool = false) -> void:
	_px[i] = randf() * area_width
	_py[i] = randf_range(-area_height * 0.5, area_height * 0.5) if random_y else area_height * 0.5
	_phase[i] = randf() * TAU
	if forest:
		# Vaga-lume: deriva lenta em qualquer direção, sobe de leve.
		_vx[i] = randf_range(-9.0, 9.0)
		_vy[i] = randf_range(-14.0, -2.0)
		_alpha[i] = randf_range(0.30, 0.70)
		_size[i] = randf_range(1.2, 2.6)
	else:
		_vx[i] = randf_range(-5.0, 5.0)
		_vy[i] = randf_range(-22.0, -6.0)
		_alpha[i] = randf_range(0.04, 0.13)
		_size[i] = randf_range(0.8, 2.4)

func _process(delta: float) -> void:
	_t += delta
	for i in particle_count:
		_px[i] += _vx[i] * delta
		_py[i] += _vy[i] * delta
		if forest:   # vaga-lume serpenteia
			_px[i] += sin(_t * 1.3 + _phase[i]) * 8.0 * delta
		if _py[i] < -area_height * 0.55 or _px[i] < -60.0 or _px[i] > area_width + 60.0:
			_init_particle(i)
	queue_redraw()

func _draw() -> void:
	if forest:
		for i in particle_count:
			var tw: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 3.2 + _phase[i]))   # piscar
			var a: float = _alpha[i] * tw
			var p := Vector2(_px[i], _py[i])
			draw_circle(p, _size[i] * 2.4, Color(0.85, 0.95, 0.45, a * 0.20))      # glow
			draw_circle(p, _size[i], Color(0.95, 1.0, 0.62, a))                    # núcleo
	else:
		for i in particle_count:
			draw_circle(Vector2(_px[i], _py[i]), _size[i], Color(0.72, 0.68, 0.88, _alpha[i]))

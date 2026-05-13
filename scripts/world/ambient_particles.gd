extends Node2D

# Floating ambient dust motes. Added procedurally by level_visuals.gd.

var area_width: float  = 5200.0
var area_height: float = 580.0
var particle_count: int = 40

var _px: PackedFloat32Array
var _py: PackedFloat32Array
var _vx: PackedFloat32Array
var _vy: PackedFloat32Array
var _alpha: PackedFloat32Array
var _size: PackedFloat32Array

func _ready() -> void:
	_px.resize(particle_count)
	_py.resize(particle_count)
	_vx.resize(particle_count)
	_vy.resize(particle_count)
	_alpha.resize(particle_count)
	_size.resize(particle_count)
	for i in particle_count:
		_init_particle(i, true)

func _init_particle(i: int, random_y: bool = false) -> void:
	_px[i]    = randf() * area_width
	_py[i]    = randf_range(-area_height * 0.5, area_height * 0.5) \
				if random_y else area_height * 0.5
	_vx[i]    = randf_range(-5.0, 5.0)
	_vy[i]    = randf_range(-22.0, -6.0)
	_alpha[i] = randf_range(0.04, 0.13)
	_size[i]  = randf_range(0.8, 2.4)

func _process(delta: float) -> void:
	for i in particle_count:
		_px[i] += _vx[i] * delta
		_py[i] += _vy[i] * delta
		if _py[i] < -area_height * 0.55 or _px[i] < -60.0 or _px[i] > area_width + 60.0:
			_init_particle(i)
	queue_redraw()

func _draw() -> void:
	for i in particle_count:
		draw_circle(Vector2(_px[i], _py[i]), _size[i],
				Color(0.72, 0.68, 0.88, _alpha[i]))

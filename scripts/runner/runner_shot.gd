extends Node2D
## Projétil do modo run-and-gun. Míssil mágico da Soph (herói) ou "bomba" do
## inimigo/boss. Detecção de acerto manual por grupos (sem depender de layers).

var vel: Vector2 = Vector2.RIGHT
var from_enemy: bool = false
var life: float = 2.2

func _ready() -> void:
	add_to_group("renemy_shot" if from_enemy else "rhero_shot")

func _draw() -> void:
	var c := Color(1.0, 0.4, 0.4) if from_enemy else Color(0.85, 0.45, 1.0)
	draw_circle(Vector2.ZERO, 7.0, Color(c.r, c.g, c.b, 0.30))
	draw_circle(Vector2.ZERO, 4.0, c)
	draw_circle(Vector2(-1, -1), 1.5, Color(1, 1, 1, 0.9))

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free(); return
	if from_enemy:
		return
	for e in get_tree().get_nodes_in_group("renemy"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) < e.hit_r:
			e.take_hit(); _pop(); return
	var b := get_tree().get_first_node_in_group("rboss")
	if b and is_instance_valid(b) and global_position.distance_to(b.global_position) < b.hit_r:
		b.take_hit(); _pop(); return

func _pop() -> void:
	VFX.burst(global_position, get_parent(), Color(0.85, 0.5, 1.0), 6, 70.0, 16.0)
	queue_free()

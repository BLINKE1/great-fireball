extends StaticBody2D
## Porta arcana (tower_door.png) que TRANCA uma passagem — gate metroidvania.
## Enquanto locked, tem colisao e o selo brilha; unlock() abre (sobe deslizando +
## fade + flash da runa + som) e libera a passagem. Portas "future" ficam
## trancadas de proposito (insinuam a area exploravel que vem depois).
##
## Uso: StaticBody2D com este script. Cria sprite + collider por codigo (nao
## precisa montar no editor). Ajuste `door_height` e `locked`.

@export var door_height: float = 150.0   # altura da passagem que a porta tapa
@export var locked: bool = true
@export var future: bool = false          # so' decorativa (area ainda nao existe)

var _sprite: Sprite2D = null
var _seal: Sprite2D = null
var _col: CollisionShape2D = null
var _t: float = 0.0

func _ready() -> void:
	add_to_group("tower_door")
	var tex := _load("res://assets/sprites/tower_door.png")
	var scale_v := door_height / (tex.get_height() if tex else 641.0)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2(scale_v, scale_v)
	_sprite.z_index = -2                    # atras do gameplay, na frente do fundo
	add_child(_sprite)
	# selo brilhante (glow aditivo) — pisca quando trancada
	_seal = Sprite2D.new()
	_seal.texture = _soft_tex()
	_seal.scale = Vector2(0.9, 1.6)
	_seal.modulate = Color(0.6, 0.3, 0.95, 0.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_seal.material = m
	add_child(_seal)
	# colisao que barra a passagem enquanto trancada
	_col = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var w: float = (tex.get_width() * scale_v * 0.5) if tex else 40.0
	rect.size = Vector2(maxf(w, 24.0), door_height)
	_col.shape = rect
	add_child(_col)
	_col.disabled = not locked
	set_process(locked)

func _process(delta: float) -> void:
	if not locked or _seal == null:
		return
	_t += delta
	_seal.modulate.a = 0.18 + 0.12 * sin(_t * 2.2)   # respiro do selo

func unlock() -> void:
	if not locked:
		return
	locked = false
	set_process(false)
	if _col:
		_col.set_deferred("disabled", true)
	AudioManager.play("chest")
	VFX.ring(global_position, get_parent(), Color(0.6, 0.35, 1.0, 0.9), 44.0, 0.5)
	VFX.burst(global_position, get_parent(), Color(0.55, 0.30, 0.95), 22, 150.0, 40.0)
	if _seal:
		var s := _seal.create_tween()
		s.tween_property(_seal, "modulate:a", 1.2, 0.12)
		s.tween_property(_seal, "modulate:a", 0.0, 0.35)
	if _sprite:
		var tw := _sprite.create_tween()
		tw.tween_property(_sprite, "position:y", -door_height, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.6)

func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r := ResourceLoader.load(path)
		if r is Texture2D:
			return r
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null

func _soft_tex() -> Texture2D:
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := (s - 1) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)

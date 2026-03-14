extends StaticBody3D

const MAX_HEALTH := 100
var health := MAX_HEALTH

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _origin: Vector3
var _move_time: float = 0.0
var move_speed: float = 0.0
var move_range: float = 2.5

func _ready() -> void:
	_origin = global_position
	# Deterministic per-target movement based on spawn position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	if rng.randf() > 0.4:
		move_speed = rng.randf_range(0.5, 1.5)
		_move_time = rng.randf() * TAU

func _process(delta: float) -> void:
	if move_speed > 0.0 and mesh_instance.visible:
		_move_time += delta * move_speed
		global_position.x = _origin.x + sin(_move_time) * move_range

func take_damage(amount: int) -> bool:
	health -= amount
	_show_damage(amount)
	if health <= 0:
		_die()
		return true
	_flash()
	return false

func _die() -> void:
	mesh_instance.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		_respawn()

func _respawn() -> void:
	health = MAX_HEALTH
	mesh_instance.visible = true
	mesh_instance.material_override = null
	global_position = _origin
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false

func _show_damage(amount: int) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 72
	label.modulate = Color(1.0, 0.9, 0.1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = global_position + Vector3(randf_range(-0.35, 0.35), 0.9, randf_range(-0.2, 0.2))
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.6, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.finished.connect(label.queue_free)

func _flash() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh_instance.material_override = mat
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and mesh_instance.visible:
		mesh_instance.material_override = null

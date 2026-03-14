extends StaticBody3D

const MAX_HEALTH := 100
var health := MAX_HEALTH

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _origin: Vector3
var _move_time: float = 0.0
var move_speed: float = 0.0
var move_range: float = 2.5

# Enemy fire
var _player: CharacterBody3D = null
var _fire_timer: float = 0.0
const FIRE_RANGE := 35.0
const WARN_DURATION := 0.5
var _warn_phase := false

func _ready() -> void:
	_origin = global_position
	# Deterministic per-target movement based on spawn position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	if rng.randf() > 0.4:
		move_speed = rng.randf_range(0.5, 1.5)
		_move_time = rng.randf() * TAU

	_player = get_tree().current_scene.get_node_or_null("Player")
	# Stagger initial fire timers so targets don't all fire at once
	_fire_timer = randf_range(1.5, 4.0)

func _process(delta: float) -> void:
	if move_speed > 0.0 and mesh_instance.visible:
		_move_time += delta * move_speed
		global_position.x = _origin.x + sin(_move_time) * move_range

	if not mesh_instance.visible or not is_instance_valid(_player):
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		if _warn_phase:
			_warn_phase = false
			_do_fire()
			_fire_timer = randf_range(1.75, 3.5)
		else:
			var dist := global_position.distance_to(_player.global_position)
			if dist <= FIRE_RANGE:
				_warn_phase = true
				_fire_timer = WARN_DURATION
				_show_warning()
			else:
				_fire_timer = randf_range(1.75, 3.5)

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
	_warn_phase = false
	_fire_timer = randf_range(1.75, 3.5)
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

func _show_warning() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 4.0
	mesh_instance.material_override = mat

func _do_fire() -> void:
	# Reset warning glow
	if mesh_instance.visible:
		mesh_instance.material_override = null

	if not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist > FIRE_RANGE:
		return

	var spawn := global_position + Vector3(0, 0.5, 0)
	var aim := (_player.global_position + Vector3(0, 0.5, 0) - spawn).normalized()

	var projectile = load("res://projectile.gd").new()
	projectile.direction = aim
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn

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

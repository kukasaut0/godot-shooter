extends StaticBody3D

const TYPE_STANDARD := 0
const TYPE_HEAVY    := 1
const TYPE_RUNNER   := 2

var enemy_type: int = TYPE_STANDARD
var mesh_height: float = 1.5
var _max_health: int = 100
var health: int = 100
var _base_color: Color = Color(1.0, 0.5, 0.0)
var _base_material: StandardMaterial3D = null
var _flash_material: StandardMaterial3D = null
var _warn_material: StandardMaterial3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _origin: Vector3
var _move_time: float = 0.0
var move_speed: float = 0.0
var move_range: float = 2.5

var _player: CharacterBody3D = null
var _fire_timer: float = 0.0
var _fire_range: float = 35.0
var _fire_min: float = 1.75
var _fire_max: float = 3.5
const WARN_DURATION := 0.5
var _warn_phase := false

func _ready() -> void:
	_origin = global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)

	# Detect enemy type from node name
	if name == "Target10":
		enemy_type = TYPE_HEAVY
	elif name in ["Target3", "Target4"]:
		enemy_type = TYPE_RUNNER

	match enemy_type:
		TYPE_STANDARD:
			health = 100
			mesh_height = 1.5
			_base_color = Color(1.0, 0.5, 0.0)
			_fire_min = 1.75
			_fire_max = 3.5
			if rng.randf() > 0.4:
				move_speed = rng.randf_range(0.5, 1.5)
				_move_time = rng.randf() * TAU
		TYPE_HEAVY:
			health = 250
			mesh_height = 2.2
			_base_color = Color(0.45, 0.08, 0.08)
			_fire_min = 1.2
			_fire_max = 2.0
			_fire_range = 50.0
			move_speed = 0.0
			var heavy_mesh := BoxMesh.new()
			heavy_mesh.size = Vector3(1.5, 2.2, 1.5)
			mesh_instance.mesh = heavy_mesh
		TYPE_RUNNER:
			health = 50
			mesh_height = 1.0
			_base_color = Color(0.1, 0.8, 0.9)
			_fire_min = 1.0
			_fire_max = 2.0
			move_range = 3.5
			var runner_mesh := BoxMesh.new()
			runner_mesh.size = Vector3(0.7, 1.0, 0.7)
			mesh_instance.mesh = runner_mesh
			if rng.randf() > 0.2:
				move_speed = rng.randf_range(1.5, 2.8)
				_move_time = rng.randf() * TAU

	_max_health = health
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = _base_color
	mesh_instance.material_override = _base_material

	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color.RED

	_warn_material = StandardMaterial3D.new()
	_warn_material.albedo_color = Color(1.0, 0.4, 0.0)
	_warn_material.emission_enabled = true
	_warn_material.emission = Color(1.0, 0.3, 0.0)
	_warn_material.emission_energy_multiplier = 4.0

	_player = get_tree().current_scene.get_node_or_null("Player")
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
			_fire_timer = randf_range(_fire_min, _fire_max)
		else:
			var dist := global_position.distance_to(_player.global_position)
			if dist <= _fire_range:
				_warn_phase = true
				_fire_timer = WARN_DURATION
				_show_warning()
			else:
				_fire_timer = randf_range(_fire_min, _fire_max)

func take_damage(amount: int, is_headshot: bool = false) -> bool:
	health -= amount
	_show_damage(amount, is_headshot)
	if is_headshot:
		Sound.play(Sound.hit_headshot, global_position)
	else:
		Sound.play(Sound.hit_enemy, global_position)
	if health <= 0:
		_die()
		return true
	_flash()
	return false

func _die() -> void:
	mesh_instance.visible = false
	_warn_phase = false
	_fire_timer = randf_range(_fire_min, _fire_max)
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

	Sound.play(Sound.death_enemy, global_position)

	# Death flash light
	var flash := OmniLight3D.new()
	flash.light_color = _base_color
	flash.light_energy = 12.0
	flash.omni_range = 5.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position
	var ft := flash.create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.25)
	ft.finished.connect(flash.queue_free)

	# Debris
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 5:
		var rb := RigidBody3D.new()
		var dm := MeshInstance3D.new()
		var dbox := BoxMesh.new()
		var ds := rng.randf_range(0.2, 0.35)
		dbox.size = Vector3(ds, ds, ds)
		dm.mesh = dbox
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = _base_color
		dm.material_override = dmat
		rb.add_child(dm)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(ds, ds, ds)
		col.shape = shape
		rb.add_child(col)
		get_tree().current_scene.add_child(rb)
		rb.global_position = global_position + Vector3(
			rng.randf_range(-0.3, 0.3), 0.2, rng.randf_range(-0.3, 0.3)
		)
		var impulse := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(1.5, 3.0),
			rng.randf_range(-1.0, 1.0)
		).normalized() * 4.0
		rb.apply_central_impulse(impulse)
		get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())

	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		_respawn()

func _respawn() -> void:
	health = _max_health
	mesh_instance.visible = true
	mesh_instance.material_override = _base_material
	global_position = _origin
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false

func _show_warning() -> void:
	mesh_instance.material_override = _warn_material

func _do_fire() -> void:
	if mesh_instance.visible:
		mesh_instance.material_override = _base_material

	if not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist > _fire_range:
		return

	Sound.play(Sound.enemy_fire, global_position)

	var spawn := global_position + Vector3(0, 0.5, 0)
	var aim := (_player.global_position + Vector3(0, 0.5, 0) - spawn).normalized()

	var projectile = load("res://projectile.gd").new()
	projectile.direction = aim
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn

func _show_damage(amount: int, is_headshot: bool = false) -> void:
	var label := Label3D.new()
	if is_headshot:
		label.text = "HEADSHOT\n%d" % amount
		label.font_size = 96
		label.modulate = Color.WHITE
	else:
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
	mesh_instance.material_override = _flash_material
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and mesh_instance.visible:
		mesh_instance.material_override = _base_material

extends Area3D

const SPEED := 25.2
const MAX_LIFETIME := 4.0

var direction := Vector3.FORWARD
var _lifetime := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.0)
	mat.emission_energy_multiplier = 6.0
	mesh.material_override = mat
	add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	col.shape = shape
	add_child(col)

	# Small trailing light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.0)
	light.light_energy = 2.0
	light.omni_range = 2.5
	add_child(light)

func _process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if _lifetime < 0.05:
		return  # ignore initial overlap with the shooting target
	if body is CharacterBody3D and body.has_method("take_damage"):
		body.take_damage(10)
	_spawn_impact()
	queue_free()

func _spawn_impact() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.0)
	light.light_energy = 6.0
	light.omni_range = 3.0
	get_tree().current_scene.add_child(light)
	light.global_position = global_position
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.12)
	tween.finished.connect(light.queue_free)

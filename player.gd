extends CharacterBody3D

const SPEED := 5.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.002
const BASE_FOV := 75.0
const SPRINT_FOV := 85.0

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D

var health := 100
var kills := 0
var shots_fired := 0
var shots_hit := 0
var session_time := 0.0

var _kill_streak := 0
var _last_kill_time := -999.0
const STREAK_WINDOW := 3.5

var wants_jump := false
var is_sprinting := false

var hud: Node          # hud.gd (CanvasLayer)
var weapon: Node       # weapon_system.gd

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = BASE_FOV

	hud = load("res://hud.gd").new()
	add_child(hud)
	hud.update_health(health)
	hud.update_kills(kills)
	hud.update_stats(0.0, 0, 0)

	weapon = load("res://weapon_system.gd").new()
	weapon.name = "WeaponSystem"
	add_child(weapon)
	weapon.setup(camera, ray, hud)
	weapon.shot_fired.connect(_on_shot_fired)
	weapon.target_hit.connect(_on_target_hit)
	weapon.target_killed.connect(_on_target_killed)

func _on_shot_fired() -> void:
	shots_fired += 1

func _on_target_hit() -> void:
	shots_hit += 1

func _on_target_killed() -> void:
	kills += 1
	hud.update_kills(kills)
	if session_time - _last_kill_time <= STREAK_WINDOW:
		_kill_streak += 1
	else:
		_kill_streak = 1
	_last_kill_time = session_time
	if _kill_streak >= 2:
		hud.show_streak(_kill_streak)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif weapon.current_weapon == weapon.Weapon.PISTOL or weapon.current_weapon == weapon.Weapon.SHOTGUN:
			weapon.shoot()
	elif event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		wants_jump = true
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventKey and event.keycode == KEY_ENTER and event.pressed and not event.echo:
		weapon.switch_weapon()
	elif event is InputEventKey and event.keycode == KEY_1 and event.pressed and not event.echo:
		weapon.select_weapon(weapon.Weapon.PISTOL)
	elif event is InputEventKey and event.keycode == KEY_2 and event.pressed and not event.echo:
		weapon.select_weapon(weapon.Weapon.MACHINE_GUN)
	elif event is InputEventKey and event.keycode == KEY_3 and event.pressed and not event.echo:
		weapon.select_weapon(weapon.Weapon.SHOTGUN)
	elif event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		weapon.start_reload()

func _physics_process(delta: float) -> void:
	session_time += delta
	hud.update_stats(session_time, shots_fired, shots_hit)

	if not is_on_floor():
		velocity += get_gravity() * delta

	if wants_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		wants_jump = false

	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and direction != Vector3.ZERO and is_on_floor()
	var effective_speed := SPRINT_SPEED if is_sprinting else SPEED

	if direction:
		velocity.x = direction.x * effective_speed
		velocity.z = direction.z * effective_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# FOV sprint zoom
	var target_fov := SPRINT_FOV if is_sprinting else BASE_FOV
	camera.fov = lerp(camera.fov, target_fov, delta * 10.0)

	weapon.process_timers(delta)
	weapon.process_bob(delta, horiz_speed, is_sprinting)

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	hud.update_health(health)
	hud.flash_damage()
	if health <= 0:
		get_tree().reload_current_scene()

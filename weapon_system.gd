extends Node

signal shot_fired
signal target_hit
signal target_killed_with_distance(dist: float)

enum Weapon { PISTOL, MACHINE_GUN, SHOTGUN }

var current_weapon := Weapon.MACHINE_GUN

var ammo         := { Weapon.PISTOL: 15,  Weapon.MACHINE_GUN: 60,  Weapon.SHOTGUN: 6  }
var max_ammo     := { Weapon.PISTOL: 15,  Weapon.MACHINE_GUN: 60,  Weapon.SHOTGUN: 6  }
var reserve_ammo := { Weapon.PISTOL: 60,  Weapon.MACHINE_GUN: 240, Weapon.SHOTGUN: 30 }
var damage       := { Weapon.PISTOL: 30,  Weapon.MACHINE_GUN: 15,  Weapon.SHOTGUN: 20 }  # shotgun: per pellet
var weapon_names := { Weapon.PISTOL: "PISTOL", Weapon.MACHINE_GUN: "MACHINE GUN", Weapon.SHOTGUN: "SHOTGUN" }
var reload_time  := { Weapon.PISTOL: 1.2, Weapon.MACHINE_GUN: 2.0, Weapon.SHOTGUN: 1.8 }
var recoil_kick  := { Weapon.PISTOL: 0.05, Weapon.MACHINE_GUN: 0.012, Weapon.SHOTGUN: 0.09 }

var is_reloading := false
var reload_timer := 0.0
var mg_fire_rate := 0.1
var mg_fire_timer := 0.0
var _shotgun_fire_timer := 0.0
const SHOTGUN_FIRE_RATE := 0.75
const SHOTGUN_PELLETS   := 8

var recoil_amount := 0.0
const RECOIL_RECOVERY := 0.18

var bob_time := 0.0
var _reload_tilt := 0.0

var weapon_root: Node3D
var pistol_mesh: MeshInstance3D
var mg_mesh: MeshInstance3D
var mg_barrel: MeshInstance3D
var shotgun_mesh: MeshInstance3D
var shotgun_barrel: MeshInstance3D

var muzzle_light: OmniLight3D
var muzzle_flash_timer := 0.0
var pistol_muzzle_flash: MeshInstance3D
var mg_muzzle_flash: MeshInstance3D
var shotgun_muzzle_flash: MeshInstance3D
var tracer_instance: MeshInstance3D
var tracer_mesh_data: ImmediateMesh
var tracer_timer := 0.0
var impact_light: OmniLight3D
var impact_timer := 0.0

var _camera: Camera3D
var _ray: RayCast3D
var _hud: Node

func setup(camera: Camera3D, ray: RayCast3D, hud: Node) -> void:
	_camera = camera
	_ray = ray
	_hud = hud
	_setup_weapon_visuals()
	_setup_effects()
	_notify_hud_ammo()

func _setup_weapon_visuals() -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "WeaponRoot"
	_camera.add_child(weapon_root)

	# --- Pistol ---
	pistol_mesh = MeshInstance3D.new()
	var pistol_body := BoxMesh.new()
	pistol_body.size = Vector3(0.06, 0.11, 0.18)
	pistol_mesh.mesh = pistol_body
	var pistol_mat := StandardMaterial3D.new()
	pistol_mat.albedo_color = Color(0.35, 0.35, 0.4)
	pistol_mat.metallic = 0.8
	pistol_mat.roughness = 0.3
	pistol_mesh.set_surface_override_material(0, pistol_mat)
	pistol_mesh.position = Vector3(0.22, -0.27, -0.42)
	weapon_root.add_child(pistol_mesh)

	var grip := MeshInstance3D.new()
	var grip_box := BoxMesh.new()
	grip_box.size = Vector3(0.05, 0.1, 0.07)
	grip.mesh = grip_box
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.15, 0.1, 0.08)
	grip.set_surface_override_material(0, grip_mat)
	grip.position = Vector3(0.0, -0.1, 0.04)
	pistol_mesh.add_child(grip)

	pistol_muzzle_flash = _make_muzzle_flash_mesh()
	pistol_muzzle_flash.position = Vector3(0.0, 0.0, -0.09)
	pistol_muzzle_flash.visible = false
	pistol_mesh.add_child(pistol_muzzle_flash)

	# --- Machine Gun ---
	mg_mesh = MeshInstance3D.new()
	var mg_body := BoxMesh.new()
	mg_body.size = Vector3(0.08, 0.11, 0.44)
	mg_mesh.mesh = mg_body
	var mg_mat := StandardMaterial3D.new()
	mg_mat.albedo_color = Color(0.18, 0.18, 0.18)
	mg_mat.metallic = 0.6
	mg_mat.roughness = 0.4
	mg_mesh.set_surface_override_material(0, mg_mat)
	mg_mesh.position = Vector3(0.22, -0.27, -0.5)
	weapon_root.add_child(mg_mesh)

	var barrel := MeshInstance3D.new()
	var barrel_box := BoxMesh.new()
	barrel_box.size = Vector3(0.03, 0.03, 0.2)
	barrel.mesh = barrel_box
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.1, 0.1, 0.1)
	barrel_mat.metallic = 0.9
	barrel.set_surface_override_material(0, barrel_mat)
	barrel.position = Vector3(0.0, 0.02, -0.32)
	mg_mesh.add_child(barrel)
	mg_barrel = barrel

	var stock := MeshInstance3D.new()
	var stock_box := BoxMesh.new()
	stock_box.size = Vector3(0.07, 0.09, 0.12)
	stock.mesh = stock_box
	var stock_mat := StandardMaterial3D.new()
	stock_mat.albedo_color = Color(0.25, 0.18, 0.12)
	stock.set_surface_override_material(0, stock_mat)
	stock.position = Vector3(0.0, 0.0, 0.28)
	mg_mesh.add_child(stock)

	mg_muzzle_flash = _make_muzzle_flash_mesh()
	mg_muzzle_flash.position = Vector3(0.0, 0.0, -0.1)
	mg_muzzle_flash.visible = false
	mg_barrel.add_child(mg_muzzle_flash)

	# --- Shotgun ---
	shotgun_mesh = MeshInstance3D.new()
	var sg_body := BoxMesh.new()
	sg_body.size = Vector3(0.09, 0.12, 0.42)
	shotgun_mesh.mesh = sg_body
	var sg_mat := StandardMaterial3D.new()
	sg_mat.albedo_color = Color(0.32, 0.24, 0.16)
	sg_mat.roughness = 0.7
	shotgun_mesh.set_surface_override_material(0, sg_mat)
	shotgun_mesh.position = Vector3(0.22, -0.27, -0.5)
	weapon_root.add_child(shotgun_mesh)

	var sg_barrel := MeshInstance3D.new()
	var sg_barrel_box := BoxMesh.new()
	sg_barrel_box.size = Vector3(0.05, 0.05, 0.48)
	sg_barrel.mesh = sg_barrel_box
	var sg_barrel_mat := StandardMaterial3D.new()
	sg_barrel_mat.albedo_color = Color(0.12, 0.12, 0.12)
	sg_barrel_mat.metallic = 0.85
	sg_barrel_mat.roughness = 0.2
	sg_barrel.set_surface_override_material(0, sg_barrel_mat)
	sg_barrel.position = Vector3(0.0, 0.04, -0.24)
	shotgun_mesh.add_child(sg_barrel)
	shotgun_barrel = sg_barrel

	var pump := MeshInstance3D.new()
	var pump_box := BoxMesh.new()
	pump_box.size = Vector3(0.07, 0.06, 0.14)
	pump.mesh = pump_box
	var pump_mat := StandardMaterial3D.new()
	pump_mat.albedo_color = Color(0.18, 0.12, 0.08)
	pump.set_surface_override_material(0, pump_mat)
	pump.position = Vector3(0.0, -0.05, -0.06)
	sg_barrel.add_child(pump)

	var sg_stock := MeshInstance3D.new()
	var sg_stock_box := BoxMesh.new()
	sg_stock_box.size = Vector3(0.08, 0.10, 0.15)
	sg_stock.mesh = sg_stock_box
	var sg_stock_mat := StandardMaterial3D.new()
	sg_stock_mat.albedo_color = Color(0.28, 0.18, 0.10)
	sg_stock.set_surface_override_material(0, sg_stock_mat)
	sg_stock.position = Vector3(0.0, -0.01, 0.27)
	shotgun_mesh.add_child(sg_stock)

	shotgun_muzzle_flash = _make_muzzle_flash_mesh()
	shotgun_muzzle_flash.position = Vector3(0.0, 0.0, -0.24)
	shotgun_muzzle_flash.visible = false
	sg_barrel.add_child(shotgun_muzzle_flash)

	_update_weapon_visibility()

func _make_muzzle_flash_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 10.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _setup_effects() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.7, 0.2)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 4.0
	_camera.add_child(muzzle_light)

	tracer_instance = MeshInstance3D.new()
	tracer_mesh_data = ImmediateMesh.new()
	tracer_instance.mesh = tracer_mesh_data
	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.albedo_color = Color(1.0, 0.95, 0.6)
	tracer_mat.emission_enabled = true
	tracer_mat.emission = Color(1.0, 0.95, 0.6)
	tracer_mat.emission_energy_multiplier = 4.0
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.no_depth_test = true
	tracer_instance.material_override = tracer_mat
	tracer_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer_instance.visible = false
	get_tree().current_scene.add_child(tracer_instance)

	impact_light = OmniLight3D.new()
	impact_light.light_color = Color(1.0, 0.5, 0.1)
	impact_light.light_energy = 0.0
	impact_light.omni_range = 3.0
	get_tree().current_scene.add_child(impact_light)

func _update_weapon_visibility() -> void:
	pistol_mesh.visible   = current_weapon == Weapon.PISTOL
	mg_mesh.visible       = current_weapon == Weapon.MACHINE_GUN
	shotgun_mesh.visible  = current_weapon == Weapon.SHOTGUN

func select_weapon(w: Weapon) -> void:
	if w == current_weapon:
		return
	current_weapon = w
	is_reloading = false
	reload_timer = 0.0
	_reload_tilt = 0.0
	weapon_root.rotation.z = 0.0
	_update_weapon_visibility()
	_notify_hud_ammo()

func switch_weapon() -> void:
	select_weapon(((current_weapon + 1) % 3) as Weapon)

func start_reload() -> void:
	if is_reloading:
		return
	if ammo[current_weapon] >= max_ammo[current_weapon]:
		return
	if reserve_ammo[current_weapon] <= 0:
		return
	is_reloading = true
	reload_timer = reload_time[current_weapon]
	_notify_hud_ammo()

func _finish_reload() -> void:
	is_reloading = false
	var needed: int = max_ammo[current_weapon] - ammo[current_weapon]
	var take: int = min(needed, reserve_ammo[current_weapon])
	ammo[current_weapon] += take
	reserve_ammo[current_weapon] -= take
	_notify_hud_ammo()

func shoot() -> void:
	if is_reloading:
		return
	if ammo[current_weapon] <= 0:
		start_reload()
		return
	if current_weapon == Weapon.SHOTGUN and _shotgun_fire_timer > 0.0:
		return

	ammo[current_weapon] -= 1
	emit_signal("shot_fired")
	_notify_hud_ammo()

	var kick: float = recoil_kick[current_weapon]
	_camera.rotation.x -= kick
	_camera.rotation.x = clamp(_camera.rotation.x, -PI / 2.0, PI / 2.0)
	recoil_amount = min(recoil_amount + kick, 0.3)

	if current_weapon == Weapon.SHOTGUN:
		_shoot_shotgun()
		_shotgun_fire_timer = SHOTGUN_FIRE_RATE
	else:
		_shoot_single()

func _shoot_single() -> void:
	_ray.force_raycast_update()
	var did_hit := _ray.is_colliding()
	var hit_target := false
	var hit_point: Vector3
	if did_hit:
		hit_point = _ray.get_collision_point()
		var collider: Object = _ray.get_collider()
		if collider.has_method("take_damage"):
			var killed: bool = collider.take_damage(damage[current_weapon])
			hit_target = true
			emit_signal("target_hit")
			if killed:
				emit_signal("target_killed_with_distance", hit_point.distance_to(_camera.global_position))
	else:
		hit_point = _camera.global_position + _camera.global_transform.basis * Vector3(0, 0, -50)
	_fire_effects(hit_point, did_hit, hit_target)

func _shoot_shotgun() -> void:
	var space_state := _camera.get_world_3d().direct_space_state
	const SPREAD := 0.07
	var any_hit := false
	var hit_any_target := false
	var last_hit_point: Vector3 = _camera.global_position - _camera.global_transform.basis.z * 50.0
	var dead_this_shot: Array = []

	for i in SHOTGUN_PELLETS:
		var fwd   := -_camera.global_transform.basis.z
		var right := _camera.global_transform.basis.x
		var up    := _camera.global_transform.basis.y
		var dir   := (fwd + right * randf_range(-SPREAD, SPREAD) + up * randf_range(-SPREAD, SPREAD)).normalized()
		var query := PhysicsRayQueryParameters3D.create(_camera.global_position, _camera.global_position + dir * 50.0)
		var result := space_state.intersect_ray(query)
		if not result:
			continue
		any_hit = true
		last_hit_point = result.position
		var collider: Object = result.collider
		if not collider.has_method("take_damage"):
			continue
		if collider in dead_this_shot:
			continue
		hit_any_target = true
		var killed: bool = collider.take_damage(damage[current_weapon])
		if killed:
			dead_this_shot.append(collider)
			emit_signal("target_killed_with_distance", result.position.distance_to(_camera.global_position))

	if hit_any_target:
		emit_signal("target_hit")
	_fire_effects(last_hit_point, any_hit, hit_any_target)

func _fire_effects(hit_point: Vector3, did_hit: bool, hit_target: bool) -> void:
	var active_flash: MeshInstance3D
	match current_weapon:
		Weapon.PISTOL:      active_flash = pistol_muzzle_flash
		Weapon.MACHINE_GUN: active_flash = mg_muzzle_flash
		Weapon.SHOTGUN:     active_flash = shotgun_muzzle_flash

	active_flash.visible = true
	muzzle_light.global_position = active_flash.global_position
	muzzle_light.light_energy = 5.0
	muzzle_flash_timer = 0.05

	tracer_mesh_data.clear_surfaces()
	tracer_mesh_data.surface_begin(Mesh.PRIMITIVE_LINES)
	tracer_mesh_data.surface_add_vertex(active_flash.global_position)
	tracer_mesh_data.surface_add_vertex(hit_point)
	tracer_mesh_data.surface_end()
	tracer_instance.visible = true
	tracer_timer = 0.05

	if did_hit:
		impact_light.global_position = hit_point
		impact_light.light_energy = 8.0
		impact_timer = 0.1

	if hit_target:
		_hud.flash_hit_marker()

func process_timers(delta: float) -> void:
	# Recoil recovery
	if recoil_amount > 0.0:
		var recover: float = min(recoil_amount, RECOIL_RECOVERY * delta)
		_camera.rotation.x += recover
		_camera.rotation.x = clamp(_camera.rotation.x, -PI / 2.0, PI / 2.0)
		recoil_amount -= recover

	# Effect timers
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0:
			muzzle_light.light_energy = 0.0
			pistol_muzzle_flash.visible = false
			mg_muzzle_flash.visible = false
			shotgun_muzzle_flash.visible = false
	if tracer_timer > 0.0:
		tracer_timer -= delta
		if tracer_timer <= 0.0:
			tracer_instance.visible = false
	if impact_timer > 0.0:
		impact_timer -= delta
		if impact_timer <= 0.0:
			impact_light.light_energy = 0.0

	# Reload countdown
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	# Machine gun auto-fire
	if mg_fire_timer > 0.0:
		mg_fire_timer -= delta
	if current_weapon == Weapon.MACHINE_GUN and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mg_fire_timer <= 0.0:
			shoot()
			mg_fire_timer = mg_fire_rate

	# Shotgun fire cooldown
	if _shotgun_fire_timer > 0.0:
		_shotgun_fire_timer -= delta

	# Reload tilt animation
	var tilt_target := -0.35 if is_reloading else 0.0
	_reload_tilt = lerp(_reload_tilt, tilt_target, delta * 10.0)
	weapon_root.rotation.z = _reload_tilt

func process_bob(delta: float, horiz_speed: float, is_sprinting: bool) -> void:
	if horiz_speed > 0.5:
		var bob_rate := 14.0 if is_sprinting else 9.0
		bob_time += delta * bob_rate
		weapon_root.position.x = sin(bob_time) * 0.007
		weapon_root.position.y = sin(bob_time * 2.0) * 0.004
	else:
		weapon_root.position = weapon_root.position.lerp(Vector3.ZERO, delta * 12.0)

func _notify_hud_ammo() -> void:
	_hud.update_ammo(
		weapon_names[current_weapon],
		ammo[current_weapon],
		max_ammo[current_weapon],
		reserve_ammo[current_weapon],
		is_reloading
	)

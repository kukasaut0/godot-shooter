extends CharacterBody3D

enum State { HIDING, SPOTTED, SEEKING_COVER, IN_COVER }

const SPOTTED_DURATION    := 0.7    # seconds of "!" before running
const VIS_CHECK_INTERVAL  := 0.12   # LOS check rate (seconds)
const MOVE_SPEED          := 4.5
const COVER_REVAL_INTERVAL := 0.6   # how often to re-score cover candidates

# Cover sampling: RINGS × SAMPLES_PER_RING candidate positions tested each search
const COVER_RINGS         := 3
const COVER_SAMPLES       := 16
const COVER_MIN_RADIUS    := 2.5
const COVER_MAX_RADIUS    := 12.0
# How much we penalise candidates that are still close to the player
const COVER_AWAY_WEIGHT   := 0.4

const SHOOT_INTERVAL  := 0.55   # seconds between shots
const RELOAD_TIME     := 2.2    # seconds to reload
const MAG_SIZE        := 5      # shots per magazine
const SHOOT_RANGE     := 35.0   # max shooting distance

var health     := 100
var mesh_height := 1.7   # used by weapon_system for headshot detection

var state           := State.HIDING
var _spotted_timer  := 0.0
var _vis_timer      := 0.0
var _cover_timer    := 0.0
var _cover_target   := Vector3.ZERO
var _cover_found    := false

var _ammo           := MAG_SIZE
var _shoot_timer    := 0.0
var _reload_timer   := 0.0
var _reloading      := false

var _player : CharacterBody3D
var _camera : Camera3D
var _label  : Label3D
var _mesh   : MeshInstance3D
var _base_mat : StandardMaterial3D
var _flash_timer := 0.0
const FLASH_DURATION := 0.15


func _ready() -> void:
	add_to_group("enemy")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not _player:
		push_warning("Enemy: could not find player node in group 'player'")
		return
	_camera = _player.get_node("Camera3D") as Camera3D

	_mesh = get_node("MeshInstance3D") as MeshInstance3D
	_base_mat = _mesh.get_active_material(0).duplicate() as StandardMaterial3D
	_mesh.set_surface_override_material(0, _base_mat)

	_label = Label3D.new()
	_label.position      = Vector3(0, 2.1, 0)
	_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size     = 28
	_label.outline_size  = 8
	_label.outline_modulate = Color.BLACK
	add_child(_label)
	_update_label()


func _physics_process(delta: float) -> void:
	if not _player:
		return

	# Throttle timers
	_vis_timer   += delta
	_cover_timer += delta
	var do_vis   := _vis_timer   >= VIS_CHECK_INTERVAL
	var do_cover := _cover_timer >= COVER_REVAL_INTERVAL
	if do_vis:   _vis_timer   = 0.0
	if do_cover: _cover_timer = 0.0

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.HIDING:
			velocity.x = 0.0
			velocity.z = 0.0
			if do_vis and _is_visible_to_player():
				_enter_spotted()

		State.SPOTTED:
			velocity.x = 0.0
			velocity.z = 0.0
			_spotted_timer -= delta
			if _spotted_timer <= 0.0:
				_enter_seeking_cover()

		State.SEEKING_COVER:
			# Periodically re-evaluate the best cover spot
			if do_cover:
				_cover_found = _find_cover_position()

			if _cover_found:
				_move_toward(_cover_target, delta)
			else:
				# No cover found yet — back away from player while searching
				_flee_from_player(delta)

			# Check if we are now hidden
			if do_vis and not _is_visible_to_player():
				_enter_in_cover()

		State.IN_COVER:
			velocity.x = 0.0
			velocity.z = 0.0
			if do_vis and _is_visible_to_player():
				_enter_spotted()

	_update_shooting(delta)
	move_and_slide()

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_base_mat.albedo_color = Color(0.85, 0.2, 0.2)


# ── State transitions ──────────────────────────────────────────────────────────

func _enter_spotted() -> void:
	state          = State.SPOTTED
	_spotted_timer = SPOTTED_DURATION
	_update_label()


func _enter_seeking_cover() -> void:
	state        = State.SEEKING_COVER
	_cover_found = false
	_cover_timer = COVER_REVAL_INTERVAL  # trigger search immediately next frame
	_update_label()


func _enter_in_cover() -> void:
	state = State.IN_COVER
	velocity.x = 0.0
	velocity.z = 0.0
	_update_label()


# ── Cover search ───────────────────────────────────────────────────────────────
#
# Samples candidate positions in rings around the enemy.  A candidate is valid
# cover if a ray from that position (at head height) to the player is blocked by
# world geometry.  Among valid candidates the one with the best score wins:
#
#   score = candidate_dist_from_player * COVER_AWAY_WEIGHT
#           - candidate_dist_from_enemy          (penalise long walks)
#
# This naturally steers the enemy away from the player and behind obstacles.

func _find_cover_position() -> bool:
	var space      := get_world_3d().direct_space_state
	var player_eye := _player.global_position + Vector3(0.0, 0.9, 0.0)
	var my_pos     := global_position

	var best_score  := -INF
	var best_pos    := Vector3.ZERO
	var found       := false

	for ring in range(COVER_RINGS):
		var t      : float = float(ring) / max(COVER_RINGS - 1, 1)
		var radius := lerpf(COVER_MIN_RADIUS, COVER_MAX_RADIUS, t)

		for i in range(COVER_SAMPLES):
			var angle     := TAU * i / COVER_SAMPLES
			var candidate := my_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

			# Keep candidate on the floor surface by dropping it slightly
			var ray_down := PhysicsRayQueryParameters3D.create(
				candidate + Vector3(0.0, 2.0, 0.0),
				candidate + Vector3(0.0, -4.0, 0.0)
			)
			ray_down.exclude = [self]
			var floor_hit := space.intersect_ray(ray_down)
			if floor_hit.is_empty():
				continue  # no floor under this sample, skip
			candidate.y = floor_hit.position.y

			# Test LOS from both mid and top of enemy body → player eye
			var head     := candidate + Vector3(0.0, 0.9, 0.0)
			var top      := candidate + Vector3(0.0, 1.6, 0.0)
			var los_head := PhysicsRayQueryParameters3D.create(head, player_eye)
			los_head.exclude = [self, _player]
			var los_top  := PhysicsRayQueryParameters3D.create(top, player_eye)
			los_top.exclude  = [self, _player]

			if space.intersect_ray(los_head).is_empty() or space.intersect_ray(los_top).is_empty():
				continue  # player can see that spot — not cover

			# Score: reward distance from player, penalise distance from self
			var dist_to_player := candidate.distance_to(_player.global_position)
			var dist_to_self   := candidate.distance_to(my_pos)
			var score          := dist_to_player * COVER_AWAY_WEIGHT - dist_to_self

			if score > best_score:
				best_score = score
				best_pos   = candidate
				found      = true

	if found:
		_cover_target = best_pos
	return found


# ── Movement helpers ───────────────────────────────────────────────────────────

func _move_toward(target: Vector3, _delta: float) -> void:
	var diff := target - global_position
	diff.y   = 0.0
	if diff.length_squared() < 0.25:  # close enough — stop drifting
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir  := diff.normalized()
	velocity.x = dir.x * MOVE_SPEED
	velocity.z = dir.z * MOVE_SPEED


func _flee_from_player(_delta: float) -> void:
	var away := (global_position - _player.global_position)
	away.y   = 0.0
	if away.length_squared() < 0.001:
		return
	var dir  := away.normalized()
	velocity.x = dir.x * MOVE_SPEED
	velocity.z = dir.z * MOVE_SPEED


# ── Visibility check ───────────────────────────────────────────────────────────

func _is_visible_to_player() -> bool:
	var head := global_position + Vector3(0.0, 0.9, 0.0)
	var top  := global_position + Vector3(0.0, 1.6, 0.0)
	if not _camera.is_position_in_frustum(head) and not _camera.is_position_in_frustum(top):
		return false
	var space      := get_world_3d().direct_space_state
	var cam_pos    := _camera.global_position
	var q_head     := PhysicsRayQueryParameters3D.create(head, cam_pos)
	q_head.exclude = [self]
	var r_head     := space.intersect_ray(q_head)
	if r_head.is_empty() or r_head.collider == _player:
		return true
	var q_top     := PhysicsRayQueryParameters3D.create(top, cam_pos)
	q_top.exclude = [self]
	var r_top     := space.intersect_ray(q_top)
	return r_top.is_empty() or r_top.collider == _player


# ── HUD label ──────────────────────────────────────────────────────────────────

func _update_label() -> void:
	match state:
		State.HIDING:
			_label.text     = "HIDING"
			_label.modulate = Color(0.6, 0.7, 1.0)
			_label.font_size = 28
		State.SPOTTED:
			_label.text     = "!"
			_label.modulate = Color(1.0, 0.9, 0.1)
			_label.font_size = 52
		State.SEEKING_COVER:
			_label.text     = "SEEKING COVER"
			_label.modulate = Color(1.0, 0.45, 0.1)
			_label.font_size = 28
		State.IN_COVER:
			_label.text     = "IN COVER"
			_label.modulate = Color(0.2, 1.0, 0.35)
			_label.font_size = 28


# ── Shooting ───────────────────────────────────────────────────────────────────

func _update_shooting(delta: float) -> void:
	# Only shoot while exposed (not hiding or in cover)
	var can_shoot := state == State.SPOTTED or state == State.SEEKING_COVER
	if not can_shoot:
		return

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			_ammo = MAG_SIZE
		return

	if _shoot_timer > 0.0:
		_shoot_timer -= delta
		return

	# Range check
	if global_position.distance_to(_player.global_position) > SHOOT_RANGE:
		return

	_fire_projectile()
	_ammo -= 1
	_shoot_timer = SHOOT_INTERVAL

	if _ammo <= 0:
		_reloading = true
		_reload_timer = RELOAD_TIME


func _fire_projectile() -> void:
	var Projectile = preload("res://projectile.gd")
	var proj : Area3D = Projectile.new()

	var muzzle := global_position + Vector3(0.0, 0.9, 0.0)
	var target  := _player.global_position + Vector3(0.0, 0.7, 0.0)  # aim at chest
	proj.direction = (target - muzzle).normalized()
	proj.global_position = muzzle

	get_tree().current_scene.add_child(proj)


# ── Death debris ───────────────────────────────────────────────────────────────

func _spawn_debris() -> void:
	const PIECE_COUNT := 8
	const LIFETIME    := 2.2
	const GRAVITY     := 14.0
	const SIZES : Array[float] = [0.18, 0.22, 0.28, 0.14]

	var scene := get_tree().current_scene
	var rng   := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(PIECE_COUNT):
		var piece     := Node3D.new()
		var mesh_inst := MeshInstance3D.new()
		var box       := BoxMesh.new()
		var s         : float = SIZES[i % SIZES.size()] * rng.randf_range(0.7, 1.4)
		box.size      = Vector3(s, s, s)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.18, 0.18)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat
		piece.add_child(mesh_inst)

		var origin := global_position + Vector3(
			rng.randf_range(-0.3, 0.3),
			rng.randf_range(0.5, 1.1),
			rng.randf_range(-0.3, 0.3)
		)
		piece.global_position = origin
		scene.add_child(piece)

		# Simulate arc with a tween — no physics bodies needed
		var vel := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(0.5, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized() * rng.randf_range(3.0, 7.0)
		var spin_axis := Vector3(rng.randf_range(-1,1), rng.randf_range(-1,1), rng.randf_range(-1,1)).normalized()
		var spin_spd  := rng.randf_range(4.0, 10.0)

		var tween := piece.create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		var elapsed := 0.0
		var steps   := 20
		for step in range(1, steps + 1):
			var t    : float = LIFETIME * step / steps
			var dt   : float = LIFETIME / steps
			elapsed += dt
			var pos  := origin + vel * t + Vector3(0, -0.5 * GRAVITY * t * t, 0)
			pos.y    = maxf(pos.y, 0.1)  # stay above floor
			var rot  := spin_axis * spin_spd * t
			tween.tween_property(piece, "global_position", pos, dt).set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(piece, "rotation", rot, dt)

		# Fade out in the last third
		tween.parallel().tween_interval(LIFETIME * 0.65)
		tween.tween_property(mat, "albedo_color:a", 0.0, LIFETIME * 0.35)
		tween.finished.connect(piece.queue_free)


func take_damage(amount: int, _is_headshot: bool = false) -> bool:
	health -= amount
	_base_mat.albedo_color = Color(1.0, 1.0, 1.0)
	_flash_timer = FLASH_DURATION
	if health <= 0:
		_spawn_debris()
		queue_free()
		return true
	# Getting hit always triggers ! → seek cover (unless already doing so)
	if state == State.HIDING or state == State.IN_COVER:
		_enter_spotted()
	return false

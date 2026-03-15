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

var health     := 100
var mesh_height := 1.7   # used by weapon_system for headshot detection

var state           := State.HIDING
var _spotted_timer  := 0.0
var _vis_timer      := 0.0
var _cover_timer    := 0.0
var _cover_target   := Vector3.ZERO
var _cover_found    := false

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

			# Test LOS: candidate head → player eye
			var head := candidate + Vector3(0.0, 0.9, 0.0)
			var los   := PhysicsRayQueryParameters3D.create(head, player_eye)
			los.exclude = [self, _player]
			var hit := space.intersect_ray(los)

			if hit.is_empty():
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
	if not _camera.is_position_in_frustum(head):
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(head, _camera.global_position)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	return result.is_empty() or result.collider == _player


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


func take_damage(amount: int, _is_headshot: bool = false) -> bool:
	health -= amount
	_base_mat.albedo_color = Color(1.0, 1.0, 1.0)
	_flash_timer = FLASH_DURATION
	if health <= 0:
		queue_free()
		return true
	# Getting hit always triggers ! → seek cover (unless already doing so)
	if state == State.HIDING or state == State.IN_COVER:
		_enter_spotted()
	return false

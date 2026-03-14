extends CanvasLayer

var label_health: Label
var label_ammo: Label
var label_weapon: Label
var label_kills: Label
var label_stats: Label
var label_streak: Label
var label_score: Label
var label_timer: Label
var crosshair: Label

var _label_headshot: Label
var _headshot_timer := 0.0
var _hit_marker_timer := 0.0
var _streak_timer := 0.0
var _damage_flash_alpha := 0.0
var _health_vignette_alpha := 0.0
var _vignette: ColorRect
var _round_over_panel: Control
var _death_panel: Control

func _ready() -> void:
	# Vignette — added first so it renders behind all labels
	_vignette = ColorRect.new()
	_vignette.color = Color(0.75, 0.0, 0.0, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	label_weapon = Label.new()
	label_weapon.add_theme_font_size_override("font_size", 18)
	label_weapon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label_weapon.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label_weapon.offset_top = -90
	label_weapon.offset_left = 10
	add_child(label_weapon)

	label_health = Label.new()
	label_health.add_theme_font_size_override("font_size", 20)
	label_health.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label_health.offset_top = -65
	label_health.offset_left = 10
	add_child(label_health)

	label_ammo = Label.new()
	label_ammo.add_theme_font_size_override("font_size", 20)
	label_ammo.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	label_ammo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label_ammo.offset_top = -40
	label_ammo.offset_left = 10
	add_child(label_ammo)

	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_top = -14
	add_child(crosshair)

	label_kills = Label.new()
	label_kills.add_theme_font_size_override("font_size", 16)
	label_kills.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	label_kills.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label_kills.offset_top = 34
	label_kills.offset_left = 10
	add_child(label_kills)

	label_stats = Label.new()
	label_stats.add_theme_font_size_override("font_size", 15)
	label_stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	label_stats.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label_stats.offset_top = 10
	label_stats.offset_right = -10
	label_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label_stats)

	# Score — top center
	label_score = Label.new()
	label_score.add_theme_font_size_override("font_size", 20)
	label_score.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label_score.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_score.offset_left = -200
	label_score.offset_right = 200
	label_score.offset_top = 10
	add_child(label_score)

	# Round timer — below score
	label_timer = Label.new()
	label_timer.add_theme_font_size_override("font_size", 22)
	label_timer.add_theme_color_override("font_color", Color.WHITE)
	label_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_timer.offset_left = -60
	label_timer.offset_right = 60
	label_timer.offset_top = 36
	add_child(label_timer)

	# Kill streak announcement — center screen, large
	label_streak = Label.new()
	label_streak.add_theme_font_size_override("font_size", 42)
	label_streak.add_theme_color_override("font_color", Color(1.0, 0.55, 0.05))
	label_streak.set_anchors_preset(Control.PRESET_CENTER)
	label_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_streak.offset_left = -250
	label_streak.offset_top = -80
	label_streak.custom_minimum_size = Vector2(500, 60)
	label_streak.visible = false
	add_child(label_streak)

	# Headshot announcement — center screen, below streak
	_label_headshot = Label.new()
	_label_headshot.text = "HEADSHOT!"
	_label_headshot.add_theme_font_size_override("font_size", 52)
	_label_headshot.add_theme_color_override("font_color", Color.WHITE)
	_label_headshot.set_anchors_preset(Control.PRESET_CENTER)
	_label_headshot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_headshot.offset_left = -250
	_label_headshot.offset_top = -20
	_label_headshot.custom_minimum_size = Vector2(500, 60)
	_label_headshot.visible = false
	add_child(_label_headshot)

	var hint := Label.new()
	hint.text = "WASD: Move  Shift: Sprint  Space: Jump  1/2/3: Weapon  RMB: Cycle  LMB: Shoot  R: Reload  Esc: Unlock mouse"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint.offset_top = 10
	hint.offset_left = 10
	add_child(hint)

func _process(delta: float) -> void:
	# Headshot label fade
	if _headshot_timer > 0.0:
		_headshot_timer -= delta
		if _headshot_timer <= 0.0:
			_label_headshot.visible = false

	# Hit marker fade
	if _hit_marker_timer > 0.0:
		_hit_marker_timer -= delta
		if _hit_marker_timer <= 0.0:
			crosshair.add_theme_color_override("font_color", Color.WHITE)

	# Streak timer
	if _streak_timer > 0.0:
		_streak_timer -= delta
		if _streak_timer <= 0.0:
			label_streak.visible = false

	# Damage flash decay
	if _damage_flash_alpha > 0.0:
		_damage_flash_alpha = max(0.0, _damage_flash_alpha - delta * 2.5)

	# Vignette: pulse when health is low, flash on damage
	if _health_vignette_alpha > 0.0 or _damage_flash_alpha > 0.0:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.18
		var total: float = max(_health_vignette_alpha * pulse, _damage_flash_alpha)
		_vignette.color.a = total
	elif _vignette.color.a != 0.0:
		_vignette.color.a = 0.0

func update_health(health: int) -> void:
	label_health.text = "HP: %d" % health
	var t := float(health) / 100.0
	label_health.add_theme_color_override("font_color", Color(1.0, t * 0.85, t * 0.85))
	_health_vignette_alpha = max(0.0, (50 - health) / 50.0) * 0.45

func update_ammo(weapon_name: String, current: int, max_val: int, reserve: int, reloading: bool) -> void:
	label_weapon.text = "[ %s ]" % weapon_name
	if reloading:
		label_ammo.text = "RELOADING..."
		label_ammo.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		label_ammo.text = "AMMO: %d / %d  +%d" % [current, max_val, reserve]
		# Low ammo warning: ≤25% of mag
		var low := max_val > 0 and current <= max_val / 4
		if low:
			label_ammo.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		else:
			label_ammo.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))

func update_kills(kills: int) -> void:
	label_kills.text = "KILLS: %d" % kills

func update_stats(time: float, shots_fired: int, shots_hit: int) -> void:
	var acc := 0
	if shots_fired > 0:
		acc = int(float(shots_hit) / float(shots_fired) * 100.0)
	var mins := int(time) / 60
	var secs := int(time) % 60
	label_stats.text = "TIME %02d:%02d  ACC %d%%" % [mins, secs, acc]

func update_score(score: int, best: int) -> void:
	if best > 0:
		label_score.text = "SCORE: %d  |  BEST: %d" % [score, best]
	else:
		label_score.text = "SCORE: %d" % score

func update_timer(t: float) -> void:
	var secs := ceili(max(0.0, t))
	label_timer.text = "0:%02d" % secs
	if secs <= 10:
		label_timer.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	else:
		label_timer.add_theme_color_override("font_color", Color.WHITE)

func show_headshot_label() -> void:
	_label_headshot.visible = true
	_headshot_timer = 1.0

func flash_hit_marker() -> void:
	crosshair.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	_hit_marker_timer = 0.12

func flash_damage() -> void:
	_damage_flash_alpha = min(_damage_flash_alpha + 0.5, 0.65)

func show_streak(count: int) -> void:
	const MESSAGES := ["", "", "DOUBLE KILL!", "TRIPLE KILL!", "QUAD KILL!", "RAMPAGE!", "UNSTOPPABLE!"]
	var msg: String
	if count >= MESSAGES.size():
		msg = "GODLIKE!  x%d" % count
	else:
		msg = MESSAGES[count]
	label_streak.text = msg
	label_streak.visible = true
	_streak_timer = 2.2

func show_round_over(score: int, best: int, kills: int, acc: int, is_new_best: bool) -> void:
	if _round_over_panel:
		_round_over_panel.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -145
	panel.offset_bottom = 145

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "ROUND OVER"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var score_lbl := Label.new()
	score_lbl.text = "SCORE:  %d" % score
	score_lbl.add_theme_font_size_override("font_size", 28)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)

	var best_lbl := Label.new()
	if is_new_best and score > 0:
		best_lbl.text = "NEW BEST!  %d" % best
		best_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		best_lbl.text = "BEST:  %d" % best
		best_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	best_lbl.add_theme_font_size_override("font_size", 20)
	best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(best_lbl)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer2)

	var stats_lbl := Label.new()
	stats_lbl.text = "KILLS: %d    ACCURACY: %d%%" % [kills, acc]
	stats_lbl.add_theme_font_size_override("font_size", 18)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)

	var next_lbl := Label.new()
	next_lbl.text = "Next round starting..."
	next_lbl.add_theme_font_size_override("font_size", 15)
	next_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(next_lbl)

	_round_over_panel = panel
	add_child(panel)

func hide_round_over() -> void:
	if _round_over_panel:
		_round_over_panel.queue_free()
		_round_over_panel = null

func show_death_screen() -> void:
	if _death_panel:
		_death_panel.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -80
	panel.offset_bottom = 80

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Respawning in 3 seconds..."
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_death_panel = panel
	add_child(panel)

func hide_death_screen() -> void:
	if _death_panel:
		_death_panel.queue_free()
		_death_panel = null

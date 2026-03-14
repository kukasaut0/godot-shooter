extends Node

var gunshot_pistol: AudioStreamWAV
var gunshot_mg: AudioStreamWAV
var gunshot_shotgun: AudioStreamWAV
var enemy_fire: AudioStreamWAV
var hit_enemy: AudioStreamWAV
var hit_headshot: AudioStreamWAV
var death_enemy: AudioStreamWAV
var player_hurt: AudioStreamWAV

const SAMPLE_RATE := 22050
const POOL_SIZE := 10
var _global_player: AudioStreamPlayer
var _pool_3d: Array = []
var _pool_idx := 0

func _ready() -> void:
	_global_player = AudioStreamPlayer.new()
	add_child(_global_player)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 50.0
		add_child(p)
		_pool_3d.append(p)

	gunshot_pistol  = _make_gunshot(0.28, 40.0)
	gunshot_mg      = _make_gunshot(0.18, 60.0)
	gunshot_shotgun = _make_gunshot(0.42, 18.0)
	enemy_fire      = _make_enemy_fire()
	hit_enemy       = _make_hit(false)
	hit_headshot    = _make_hit(true)
	death_enemy     = _make_death()
	player_hurt     = _make_player_hurt()

func play(stream: AudioStreamWAV, pos: Vector3 = Vector3.ZERO) -> void:
	if pos == Vector3.ZERO:
		_global_player.stream = stream
		_global_player.play()
	else:
		var p3d: AudioStreamPlayer3D = _pool_3d[_pool_idx]
		_pool_idx = (_pool_idx + 1) % POOL_SIZE
		p3d.stream = stream
		p3d.global_position = pos
		p3d.play()

func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := int(clamp(buf[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2]     = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = bytes
	return wav

func _make_gunshot(duration: float, decay: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(decay * 1000.0)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		buf[i] = rng.randf_range(-1.0, 1.0) * exp(-t * decay)
	return _to_wav(buf)

func _make_enemy_fire() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.15)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq: float = lerp(300.0, 150.0, t / 0.15)
		phase += freq / SAMPLE_RATE
		buf[i] = sin(TAU * phase) * (1.0 - t / 0.15) * 0.7
	return _to_wav(buf)

func _make_hit(headshot: bool) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.06)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55555 if headshot else 44444
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 80.0)
		buf[i] = rng.randf_range(-1.0, 1.0) * env
		if headshot:
			buf[i] = clamp(buf[i] + sin(TAU * 1400.0 * t) * env * 0.5, -1.0, 1.0)
	return _to_wav(buf)

func _make_death() -> AudioStreamWAV:
	var duration := 0.35
	var n := int(SAMPLE_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 8.0)
		var freq: float = lerp(200.0, 80.0, t / duration)
		phase += freq / SAMPLE_RATE
		buf[i] = clamp(
			rng.randf_range(-0.6, 0.6) * env +
			sin(TAU * phase) * (1.0 - t / duration) * 0.45,
			-1.0, 1.0
		)
	return _to_wav(buf)

func _make_player_hurt() -> AudioStreamWAV:
	var duration := 0.2
	var n := int(SAMPLE_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 12.0)
		buf[i] = clamp(
			rng.randf_range(-0.6, 0.6) * env +
			sin(TAU * 80.0 * t) * env * 0.45,
			-1.0, 1.0
		)
	return _to_wav(buf)

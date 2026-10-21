extends Node

# Procedural Retro/Action Audio Synthesizer for Dungeon Survivor
# Generates 16-bit PCM waveforms at runtime using AudioStreamWAV without external assets.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 12

var _player_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

# Cached Audio Streams
var stream_slash: AudioStreamWAV
var stream_hit: AudioStreamWAV
var stream_crit: AudioStreamWAV
var stream_dash: AudioStreamWAV
var stream_player_hurt: AudioStreamWAV
var stream_wave_fanfare: AudioStreamWAV
var stream_special: AudioStreamWAV
var stream_cast: AudioStreamWAV
var stream_boss_slam: AudioStreamWAV
var stream_bgm_combat: AudioStreamWAV
var stream_bgm_boss: AudioStreamWAV
var stream_lava_bubble: AudioStreamWAV
var stream_lava_erupt: AudioStreamWAV
var stream_rock_crash: AudioStreamWAV
var stream_volcanic_rumble: AudioStreamWAV

var _bgm_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Instantiate audio player pool
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_player_pool.append(p)
	
	# Instantiate dedicated looping BGM player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = &"Master"
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)
	
	# Instantiate dedicated looping ambient player
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = &"Master"
	_ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambient_player)
	
	# Synthesize all waveforms once on startup
	_generate_all_streams()
	start_bgm()

# --- Public Play API ---

func start_bgm() -> void:
	if not _bgm_player or not stream_bgm_combat:
		return
	_bgm_player.stream = stream_bgm_combat
	_bgm_player.volume_db = -10.0
	_bgm_player.play()

func set_boss_bgm(is_boss: bool) -> void:
	if not _bgm_player:
		return
	var target_stream := stream_bgm_boss if is_boss else stream_bgm_combat
	if _bgm_player.stream != target_stream:
		_bgm_player.stream = target_stream
		_bgm_player.volume_db = -7.0 if is_boss else -10.0
		_bgm_player.play()


func play_slash() -> void:
	_play_stream(stream_slash, -2.0, randf_range(0.92, 1.08))

func play_hit() -> void:
	_play_stream(stream_hit, 0.0, randf_range(0.95, 1.1))

func play_crit() -> void:
	_play_stream(stream_crit, 2.0, randf_range(0.97, 1.05))

func play_dash() -> void:
	_play_stream(stream_dash, -3.0, randf_range(0.95, 1.05))

func play_player_hurt() -> void:
	_play_stream(stream_player_hurt, 2.5, randf_range(0.95, 1.05))

func play_wave_fanfare() -> void:
	_play_stream(stream_wave_fanfare, 1.0, 1.0)

func play_fanfare() -> void:
	play_wave_fanfare()

func play_pickup_heal() -> void:
	play_wave_fanfare()

func play_pickup_score() -> void:
	play_crit()

func play_soul_gem() -> void:
	play_wave_fanfare()

func play_special() -> void:
	_play_stream(stream_special, 3.0, randf_range(0.95, 1.05))

func play_cast() -> void:
	_play_stream(stream_cast, -1.0, randf_range(0.95, 1.1))

func play_boss_slam() -> void:
	_play_stream(stream_boss_slam, 4.0, randf_range(0.92, 1.02))

func play_combat_music() -> void:
	start_bgm()

func transition_to_boss() -> void:
	set_boss_bgm(true)

func transition_to_combat() -> void:
	set_boss_bgm(false)

func set_boss_music_intensity(multiplier: float) -> void:
	if _bgm_player:
		_bgm_player.pitch_scale = clampf(multiplier, 0.8, 1.5)

func duck_music(ducked: bool) -> void:
	if _bgm_player:
		_bgm_player.volume_db = -18.0 if ducked else -10.0

func play_crate_break() -> void:
	play_hit()

func play_barrel_explode() -> void:
	play_boss_slam()

func play_hazard_spike() -> void:
	play_slash()

func play_lava_bubble() -> void:
	_play_stream(stream_lava_bubble, -1.0, randf_range(0.92, 1.08))

func play_lava_erupt() -> void:
	_play_stream(stream_lava_erupt, 2.0, randf_range(0.95, 1.05))

func play_lava_whoosh() -> void:
	play_lava_erupt()

func play_rock_crash() -> void:
	_play_stream(stream_rock_crash, 3.5, randf_range(0.94, 1.04))

func play_stalactite_impact() -> void:
	play_rock_crash()

func play_volcanic_rumble() -> void:
	_play_stream(stream_volcanic_rumble, -6.0, 1.0)

func start_volcanic_ambience() -> void:
	if not _ambient_player or not stream_volcanic_rumble:
		return
	_ambient_player.stream = stream_volcanic_rumble
	_ambient_player.volume_db = -12.0
	if not _ambient_player.playing:
		_ambient_player.play()

func stop_volcanic_ambience() -> void:
	if _ambient_player and _ambient_player.playing:
		_ambient_player.stop()

func set_volcanic_ambience(active: bool) -> void:
	if active:
		start_volcanic_ambience()
	else:
		stop_volcanic_ambience()

func _play_stream(stream: AudioStreamWAV, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream or _player_pool.is_empty():
		return
	var player := _player_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _player_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

# --- Waveform Synthesis ---

func _generate_all_streams() -> void:
	stream_slash = _synth_slash()
	stream_hit = _synth_hit()
	stream_crit = _synth_crit()
	stream_dash = _synth_dash()
	stream_player_hurt = _synth_hurt()
	stream_wave_fanfare = _synth_fanfare()
	stream_special = _synth_special()
	stream_cast = _synth_cast()
	stream_boss_slam = _synth_boss_slam()
	stream_bgm_combat = _synth_bgm(false)
	stream_bgm_boss = _synth_bgm(true)
	stream_lava_bubble = _synth_lava_bubble()
	stream_lava_erupt = _synth_lava_erupt()
	stream_rock_crash = _synth_rock_crash()
	stream_volcanic_rumble = _synth_volcanic_rumble()

func _create_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	
	var count := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var val := clampf(samples[i], -1.0, 1.0)
		var s16 := clampi(int(val * 32760.0), -32767, 32767)
		bytes.encode_s16(i * 2, s16)
	
	wav.data = bytes
	return wav

func _synth_slash() -> AudioStreamWAV:
	# Quick swoosh: White noise + rapid frequency sweep downwards
	var duration: float = 0.13
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		# Frequency sweeps from 650 Hz down to 130 Hz
		var freq: float = lerpf(650.0, 130.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		
		# Envelope: fast rise, exponential fall
		var env: float = (1.0 - t) * (1.0 - t)
		if t < 0.15:
			env *= (t / 0.15)
		
		var tone := sin(phase) * 0.4
		var noise := randf_range(-1.0, 1.0) * 0.6
		samples[i] = (tone + noise) * env * 0.75
	
	return _create_wav(samples)

func _synth_hit() -> AudioStreamWAV:
	# Punchy impact thud: 160 Hz -> 40 Hz with initial crunch transient
	var duration: float = 0.11
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var freq: float = lerpf(170.0, 42.0, sqrt(t))
		phase += TAU * freq / float(SAMPLE_RATE)
		
		var env := exp(-18.0 * t)
		var tone := sin(phase)
		# Add a touch of clipped overdrive
		var raw := tone * 1.4
		var clipped := clampf(raw, -0.9, 0.9)
		
		var noise := 0.0
		if t < 0.2:
			noise = randf_range(-0.5, 0.5) * (1.0 - t / 0.2)
		
		samples[i] = (clipped + noise) * env * 0.85
	
	return _create_wav(samples)

func _synth_crit() -> AudioStreamWAV:
	# High metallic chime + resonant punch
	var duration: float = 0.28
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase_low: float = 0.0
	var phase_hi1: float = 0.0
	var phase_hi2: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var low_freq: float = lerpf(120.0, 38.0, t)
		phase_low += TAU * low_freq / float(SAMPLE_RATE)
		phase_hi1 += TAU * 1174.66 / float(SAMPLE_RATE) # D6 chime
		phase_hi2 += TAU * 1760.0 / float(SAMPLE_RATE)  # A6 overtone
		
		var env_low := exp(-12.0 * t)
		var env_hi := exp(-7.0 * t)
		
		var low_tone := sin(phase_low) * env_low * 0.6
		var hi_tone := (sin(phase_hi1) * 0.6 + sin(phase_hi2) * 0.4) * env_hi * 0.45
		
		samples[i] = (low_tone + hi_tone) * 0.9
	
	return _create_wav(samples)

func _synth_dash() -> AudioStreamWAV:
	# Clean air burst swoosh
	var duration: float = 0.16
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		# Arc frequency up then down
		var freq: float = 200.0 + 380.0 * sin(t * PI)
		phase += TAU * freq / float(SAMPLE_RATE)
		
		var env := sin(t * PI)
		var noise := randf_range(-1.0, 1.0) * 0.55
		var tone := sin(phase) * 0.45
		samples[i] = (tone + noise) * env * 0.65
	
	return _create_wav(samples)

func _synth_hurt() -> AudioStreamWAV:
	# Heavy player damage grunt/thump
	var duration: float = 0.17
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var freq: float = lerpf(140.0, 50.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		
		var env := exp(-10.0 * t)
		# Distorted gritty waveform
		var s := sin(phase)
		var distorted := s * 1.6 - 0.6 * (s * s * s)
		var noise := randf_range(-0.3, 0.3) * exp(-20.0 * t)
		samples[i] = (distorted + noise) * env * 0.75
	
	return _create_wav(samples)

func _synth_fanfare() -> AudioStreamWAV:
	# Triumphant 4-tone ascending arpeggio chime: C5 (523), E5 (659), G5 (784), C6 (1046)
	var duration: float = 0.72
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var notes := [523.25, 659.25, 783.99, 1046.50]
	var note_duration: float = 0.13
	
	for note_idx in range(notes.size()):
		var note_freq: float = notes[note_idx]
		var start_time: float = float(note_idx) * note_duration
		var start_sample: int = int(start_time * SAMPLE_RATE)
		var end_sample: int = total_samples
		
		var phase: float = 0.0
		var phase_harm: float = 0.0
		for i in range(start_sample, end_sample):
			var local_t := float(i - start_sample) / float(SAMPLE_RATE)
			phase += TAU * note_freq / float(SAMPLE_RATE)
			phase_harm += TAU * (note_freq * 2.0) / float(SAMPLE_RATE)
			
			var env := exp(-6.5 * local_t)
			var val := (sin(phase) * 0.7 + sin(phase_harm) * 0.3) * env * 0.28
			samples[i] += val
	
	return _create_wav(samples)

func _synth_special() -> AudioStreamWAV:
	# Ground slam seismic shockwave: Sub drop + heavy explosion crunch
	var duration: float = 0.38
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var freq: float = lerpf(130.0, 28.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		
		var env := exp(-7.5 * t)
		var sub := sin(phase)
		var sub_dist := clampf(sub * 1.8, -1.0, 1.0)
		var noise := randf_range(-0.7, 0.7) * exp(-14.0 * t)
		samples[i] = (sub_dist * 0.65 + noise * 0.35) * env * 0.95
	
	return _create_wav(samples)

func _synth_cast() -> AudioStreamWAV:
	# Arcane dark energy orb cast / missile whoosh
	var duration: float = 0.22
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var freq: float = 340.0 + 380.0 * sin(t * PI)
		# Subtle pitch vibrato
		freq += sin(float(i) * 0.04) * 25.0
		phase += TAU * freq / float(SAMPLE_RATE)
		
		var env := sin(t * PI)
		var tone := sin(phase)
		samples[i] = tone * env * 0.6
	
	return _create_wav(samples)

func _synth_boss_slam() -> AudioStreamWAV:
	# Massive colossal boss ground impact
	var duration: float = 0.55
	var total_samples: int = int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var freq: float = lerpf(90.0, 22.0, t * t)
		phase += TAU * freq / float(SAMPLE_RATE)
		
		var env := exp(-5.0 * t)
		var sub := sin(phase)
		var noise := randf_range(-0.8, 0.8) * exp(-12.0 * t)
		var val := clampf(sub * 2.0 + noise, -1.0, 1.0)
		samples[i] = val * env * 0.95
	
	return _create_wav(samples)

func _synth_bgm(is_boss: bool) -> AudioStreamWAV:
	# Looping dark-synth bassline & pulse rhythm
	var bpm: float = 135.0 if is_boss else 110.0
	var beat_duration: float = 60.0 / bpm
	var total_beats: int = 8
	var duration: float = beat_duration * float(total_beats)
	var total_samples: int = int(duration * float(SAMPLE_RATE))
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var bass_notes: PackedFloat32Array = PackedFloat32Array([55.0, 65.4, 73.4, 82.4]) if not is_boss else PackedFloat32Array([43.6, 51.9, 58.2, 65.4])
	
	for i in range(total_samples):
		var time := float(i) / float(SAMPLE_RATE)
		var current_beat := int(time / beat_duration) % total_beats
		var beat_time := fmod(time, beat_duration)
		var beat_progress := beat_time / beat_duration
		
		# Kick pulse
		var kick := 0.0
		if beat_progress < 0.22:
			var kick_env := 1.0 - (beat_progress / 0.22)
			var kick_freq := lerpf(140.0, 40.0, 1.0 - kick_env)
			kick = sin(TAU * kick_freq * beat_time) * kick_env * 0.4
		
		# Synth bass
		var note_idx := current_beat % bass_notes.size()
		var base_freq: float = bass_notes[note_idx]
		var bass_env := exp(-beat_progress * 4.2)
		var phase := TAU * base_freq * beat_time
		var bass := (sin(phase) * 0.35 + sin(phase * 2.0) * 0.18 + sin(phase * 3.0) * 0.08) * bass_env
		
		# Hi-hat tick
		var hat := 0.0
		if beat_progress > 0.45 and beat_progress < 0.65:
			var hat_progress := (beat_progress - 0.45) / 0.2
			var hat_env := 1.0 - hat_progress
			hat = randf_range(-0.8, 0.8) * hat_env * 0.06
		
		var sample := kick + bass + hat
		samples[i] = clampf(sample, -0.85, 0.85)
	
	var wav := _create_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav

func _synth_lava_bubble() -> AudioStreamWAV:
	# Molten lava bubbling: chirp sweeps with 3 overlapping bubbling pops + magma rumble
	var duration: float = 0.28
	var total_samples: int = int(duration * float(SAMPLE_RATE))
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var pop_starts := [0.0, 0.08, 0.17]
	var pop_f_start := [140.0, 190.0, 120.0]
	var pop_f_end := [280.0, 360.0, 240.0]
	var pop_durs := [0.10, 0.09, 0.11]
	
	for k in range(3):
		var start_time: float = pop_starts[k]
		var start_idx: int = int(start_time * float(SAMPLE_RATE))
		var f0: float = pop_f_start[k]
		var f1: float = pop_f_end[k]
		var pop_dur: float = pop_durs[k]
		var end_idx: int = mini(total_samples, start_idx + int(pop_dur * float(SAMPLE_RATE)))
		
		var phase: float = 0.0
		for i in range(start_idx, end_idx):
			var tau: float = float(i - start_idx) / float(SAMPLE_RATE)
			var progress: float = clampf(tau / pop_dur, 0.0, 1.0)
			var freq: float = f0 + (f1 - f0) * (progress * progress)
			phase += TAU * freq / float(SAMPLE_RATE)
			
			var attack: float = sin(PI * 0.5 * minf(1.0, tau / 0.015))
			var env: float = exp(-32.0 * tau) * attack
			var pop_tone: float = sin(phase) * env * 0.70
			var magma_noise: float = randf_range(-0.15, 0.15) * exp(-18.0 * tau)
			
			samples[i] += pop_tone + magma_noise * env
	
	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var rumble: float = sin(TAU * 55.0 * t) * 0.15 * (1.0 - t / duration)
		samples[i] = clampf(samples[i] + rumble, -0.90, 0.90)
	
	return _create_wav(samples)

func _synth_lava_erupt() -> AudioStreamWAV:
	# Molten lava eruption whoosh: Sub-sweep (75->170->75 Hz) + shaped broadband noise whoosh
	var duration: float = 0.50
	var total_samples: int = int(duration * float(SAMPLE_RATE))
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		
		# Frequency modulation sweep
		var freq: float = 75.0 + 95.0 * sin(PI * progress)
		phase += TAU * freq / float(SAMPLE_RATE)
		var sub_tone: float = sin(phase) * 0.40
		
		# Asymmetrical noise whoosh envelope
		var env_noise: float = sin(PI * pow(progress, 0.75)) * exp(-2.2 * t)
		var noise: float = randf_range(-0.8, 0.8) * env_noise * 0.60
		
		# Overdrive saturation
		var raw: float = (sub_tone + noise) * 1.5
		samples[i] = clampf(raw, -0.92, 0.92)
	
	return _create_wav(samples)

func _synth_rock_crash() -> AudioStreamWAV:
	# Heavy rock impact crash: High-frequency snap transient + heavy sub thud + debris crunch tail
	var duration: float = 0.48
	var total_samples: int = int(duration * float(SAMPLE_RATE))
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	var phase_snap: float = 0.0
	var phase_sub: float = 0.0
	
	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		
		# 1. Transient stone snap (0 - 30ms)
		var snap: float = 0.0
		if t < 0.03:
			var snap_progress: float = t / 0.03
			var f_snap: float = lerpf(850.0, 220.0, snap_progress)
			phase_snap += TAU * f_snap / float(SAMPLE_RATE)
			var snap_tone: float = sin(phase_snap) * exp(-45.0 * t) * 0.55
			var snap_noise: float = randf_range(-0.6, 0.6) * exp(-60.0 * t) * 0.45
			snap = snap_tone + snap_noise
		
		# 2. Sub impact thud
		var f_sub: float = lerpf(120.0, 26.0, progress * progress)
		phase_sub += TAU * f_sub / float(SAMPLE_RATE)
		var sub_thud: float = sin(phase_sub) * exp(-7.5 * t) * 0.70
		
		# 3. Debris crunch tail
		var debris: float = randf_range(-0.5, 0.5) * exp(-9.0 * t) * 0.35
		
		samples[i] = clampf(snap + sub_thud + debris, -0.95, 0.95)
	
	return _create_wav(samples)

func _synth_volcanic_rumble() -> AudioStreamWAV:
	# Volcanic ambient low-frequency rumble: seamless looping detuned sub-bass rumble
	var duration: float = 3.20
	var total_samples: int = int(duration * float(SAMPLE_RATE))
	var crossfade_samples: int = int(0.05 * float(SAMPLE_RATE))
	
	var raw_samples := PackedFloat32Array()
	raw_samples.resize(total_samples + crossfade_samples)
	
	var phase_1: float = 0.0
	var phase_2: float = 0.0
	var phase_3: float = 0.0
	
	for i in range(total_samples + crossfade_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		phase_1 += TAU * 34.0 / float(SAMPLE_RATE)
		phase_2 += TAU * 41.5 / float(SAMPLE_RATE)
		phase_3 += TAU * 49.0 / float(SAMPLE_RATE)
		
		var sub_bass: float = 0.30 * sin(phase_1) + 0.22 * sin(phase_2) + 0.15 * sin(phase_3)
		var lfo: float = 0.75 + 0.25 * sin(TAU * 0.625 * t)
		var noise_mod: float = (sin(phase_1) * 0.5 + 0.5) * 0.30
		var rumble_noise: float = randf_range(-0.25, 0.25) * noise_mod
		
		raw_samples[i] = (sub_bass * lfo) + rumble_noise
	
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	
	# Loop seam matching: cosine crossfade window at start/end ensuring zero DC offset or click
	for i in range(crossfade_samples):
		var blend: float = float(i) / float(crossfade_samples)
		var w: float = 0.5 * (1.0 - cos(PI * blend))
		samples[i] = clampf(raw_samples[i] * w + raw_samples[total_samples + i] * (1.0 - w), -0.85, 0.85)
	
	for i in range(crossfade_samples, total_samples):
		samples[i] = clampf(raw_samples[i], -0.85, 0.85)
	
	var wav := _create_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav



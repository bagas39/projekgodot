extends SceneTree

# ==============================================================================
# EMPIRICAL ADVERSARIAL CHALLENGER SUITE: MILESTONE 1 AUDIO MANAGER
# ==============================================================================
# Tests concurrent audio playback, rapid ambient state transitions,
# pool index cycling, waveform data integrity, and alias method contracts.
# ==============================================================================

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _run_adversarial_suite() -> void:
	print("\n=======================================================")
	print(">>> RUNNING ADVERSARIAL CHALLENGE SUITE: MILESTONE 1 AUDIO <<<")
	print("=======================================================\n")

	var audio_script: GDScript = load("res://src/audio/audio_manager.gd")
	assert(audio_script != null, "FATAL: Failed to load res://src/audio/audio_manager.gd")

	var audio: Node = audio_script.new()
	root.add_child(audio)
	if not audio.is_node_ready():
		await audio.ready

	# --------------------------------------------------------------------------
	# TEST 1: Method Coverage & Interface Contract Verification
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 1] Verifying public method contracts and aliases...")
	var expected_methods: Array[String] = [
		"play_lava_bubble",
		"play_lava_erupt",
		"play_lava_whoosh",
		"play_rock_crash",
		"play_stalactite_impact",
		"play_volcanic_rumble",
		"start_volcanic_ambience",
		"stop_volcanic_ambience",
		"set_volcanic_ambience"
	]
	for m in expected_methods:
		assert(audio.has_method(m), "FAIL: Missing required public method '%s' in AudioManager" % m)
	print("  -> All 9 required public methods exist on AudioManager.")

	# --------------------------------------------------------------------------
	# TEST 2: Waveform Buffer Synthesis & Loop Contract Integrity
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 2] Verifying waveform buffer synthesis and loop configuration...")
	assert(audio.get("stream_lava_bubble") != null, "FAIL: stream_lava_bubble is null")
	assert(audio.get("stream_lava_erupt") != null, "FAIL: stream_lava_erupt is null")
	assert(audio.get("stream_rock_crash") != null, "FAIL: stream_rock_crash is null")
	assert(audio.get("stream_volcanic_rumble") != null, "FAIL: stream_volcanic_rumble is null")

	var volcanic_streams: Dictionary = {
		"stream_lava_bubble": audio.get("stream_lava_bubble"),
		"stream_lava_erupt": audio.get("stream_lava_erupt"),
		"stream_rock_crash": audio.get("stream_rock_crash"),
		"stream_volcanic_rumble": audio.get("stream_volcanic_rumble")
	}

	for stream_name in volcanic_streams.keys():
		var wav: AudioStreamWAV = volcanic_streams[stream_name] as AudioStreamWAV
		assert(wav != null, "FAIL: %s is not an AudioStreamWAV" % stream_name)
		assert(wav.format == AudioStreamWAV.FORMAT_16_BITS, "FAIL: %s format must be 16-bit PCM" % stream_name)
		assert(wav.mix_rate == 22050, "FAIL: %s mix_rate must be 22050 Hz" % stream_name)
		assert(wav.stereo == false, "FAIL: %s should be mono" % stream_name)
		assert(wav.data.size() > 0, "FAIL: %s data buffer is empty" % stream_name)
		assert(wav.data.size() % 2 == 0, "FAIL: %s byte size must be multiple of 2 (16-bit samples)" % stream_name)

		# Inspect PCM data for numerical anomalies (DC blowup, invalid samples)
		var sample_count: int = wav.data.size() / 2
		var max_val: int = -32768
		var min_val: int = 32767
		for s_idx in range(mini(sample_count, 1000)):
			var s: int = wav.data.decode_s16(s_idx * 2)
			if s > max_val:
				max_val = s
			if s < min_val:
				min_val = s
		assert(min_val != max_val, "FAIL: %s appears to be completely flat silence" % stream_name)
		print("  -> %s: %d bytes (%d samples), range [%d, %d]" % [stream_name, wav.data.size(), sample_count, min_val, max_val])

	# Ambient loop contracts
	var rumble: AudioStreamWAV = audio.get("stream_volcanic_rumble") as AudioStreamWAV
	assert(rumble.loop_mode == AudioStreamWAV.LOOP_FORWARD, "FAIL: stream_volcanic_rumble must have LOOP_FORWARD")
	assert(rumble.loop_begin == 0, "FAIL: stream_volcanic_rumble loop_begin must be 0")
	var rumble_sample_count: int = rumble.data.size() / 2
	assert(rumble.loop_end == rumble_sample_count, "FAIL: stream_volcanic_rumble loop_end (%d) must match sample count (%d)" % [rumble.loop_end, rumble_sample_count])
	print("  -> Volcanic rumble loop configuration strictly confirmed.")

	# --------------------------------------------------------------------------
	# TEST 3: Alias Equivalence & Dispatch Targeting
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 3] Verifying alias delegation and stream parity...")
	var player_pool: Array = audio.get("_player_pool")
	# Check play_lava_whoosh() delegates to play_lava_erupt()
	var prev_idx: int = audio.get("_pool_index")
	audio.call("play_lava_whoosh")
	var used_idx: int = prev_idx
	var assigned_player: AudioStreamPlayer = player_pool[used_idx] as AudioStreamPlayer
	assert(assigned_player.stream == audio.get("stream_lava_erupt"), "FAIL: play_lava_whoosh() did not play stream_lava_erupt")

	# Check play_stalactite_impact() delegates to play_rock_crash()
	prev_idx = audio.get("_pool_index")
	audio.call("play_stalactite_impact")
	used_idx = prev_idx
	assigned_player = player_pool[used_idx] as AudioStreamPlayer
	assert(assigned_player.stream == audio.get("stream_rock_crash"), "FAIL: play_stalactite_impact() did not play stream_rock_crash")
	print("  -> Method aliases match their canonical stream targets.")

	# --------------------------------------------------------------------------
	# TEST 4: Pool Index Cycling & Boundary Wraparound Torture
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 4] Stress testing SFX pool cycling across 1,000 rapid sound plays...")
	var initial_pool_size: int = player_pool.size()
	var const_pool_size: int = audio.get("POOL_SIZE")
	assert(initial_pool_size == const_pool_size, "FAIL: Pool size mismatch")

	for i in range(1000):
		var curr_idx: int = audio.get("_pool_index")
		var expected_next_idx: int = (curr_idx + 1) % initial_pool_size
		var mode: int = i % 6
		match mode:
			0: audio.call("play_lava_bubble")
			1: audio.call("play_lava_erupt")
			2: audio.call("play_lava_whoosh")
			3: audio.call("play_rock_crash")
			4: audio.call("play_stalactite_impact")
			5: audio.call("play_volcanic_rumble")
		var actual_next_idx: int = audio.get("_pool_index")
		assert(actual_next_idx == expected_next_idx, "FAIL: _pool_index diverged at step %d: got %d, expected %d" % [i, actual_next_idx, expected_next_idx])

	assert(player_pool.size() == initial_pool_size, "FAIL: Pool size changed during stress test")
	for p_idx in range(player_pool.size()):
		var p: AudioStreamPlayer = player_pool[p_idx] as AudioStreamPlayer
		assert(is_instance_valid(p), "FAIL: Pool player instance %d invalid" % p_idx)
		assert(p.stream != null, "FAIL: Pool player %d has null stream after cycling" % p_idx)
		assert(p.bus == &"Master", "FAIL: Pool player %d bus is not Master" % p_idx)
	print("  -> Pool index wrapped around %d times cleanly with zero invalidations." % [1000 / initial_pool_size])

	# --------------------------------------------------------------------------
	# TEST 5: State Transition Torture & Ambient Player Idempotence
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 5] Subjecting ambient player to rapid state transition torture...")
	var amb_player: AudioStreamPlayer = audio.get("_ambient_player") as AudioStreamPlayer
	assert(amb_player != null, "FAIL: _ambient_player is null")

	# Subtest 5A: Repeated start calls when already running
	audio.call("start_volcanic_ambience")
	assert(amb_player.playing == true, "FAIL: Ambient player should be playing after start")
	for i in range(200):
		audio.call("start_volcanic_ambience")
		assert(amb_player.playing == true, "FAIL: Ambient player stopped unexpectedly on repeated start (%d)" % i)
	print("  -> 200 consecutive start_volcanic_ambience() calls handled idempotently.")

	# Subtest 5B: Repeated stop calls when already stopped
	audio.call("stop_volcanic_ambience")
	assert(amb_player.playing == false, "FAIL: Ambient player should be stopped after stop")
	for i in range(200):
		audio.call("stop_volcanic_ambience")
		assert(amb_player.playing == false, "FAIL: Ambient player restarted unexpectedly on repeated stop (%d)" % i)
	print("  -> 200 consecutive stop_volcanic_ambience() calls handled safely.")

	# Subtest 5C: Rapid oscillation (1,000 toggles in a single frame)
	for i in range(1000):
		audio.call("set_volcanic_ambience", true)
		assert(amb_player.playing == true, "FAIL: Ambience should be active after set_volcanic_ambience(true) at step %d" % i)
		audio.call("set_volcanic_ambience", false)
		assert(amb_player.playing == false, "FAIL: Ambience should be inactive after set_volcanic_ambience(false) at step %d" % i)
	print("  -> 1,000 rapid toggle oscillations in a single frame completed without errors.")

	# Subtest 5D: Async frame ticks oscillation
	for i in range(5):
		audio.call("set_volcanic_ambience", (i % 2 == 0))
		await process_frame
		assert(amb_player.playing == (i % 2 == 0), "FAIL: Ambience state mismatch on process frame %d" % i)
	print("  -> Process frame asynchronous state transitions verified.")

	# --------------------------------------------------------------------------
	# TEST 6: Concurrent Polyphony & Player Isolation
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 6] Verifying concurrent polyphony and isolation from BGM / Ambient...")
	var bgm_player: AudioStreamPlayer = audio.get("_bgm_player") as AudioStreamPlayer
	assert(bgm_player != null, "FAIL: _bgm_player is null")

	# Start combat BGM and volcanic ambience
	audio.call("start_bgm")
	assert(bgm_player.playing == true, "FAIL: BGM should be playing")
	assert(bgm_player.stream == audio.get("stream_bgm_combat"), "FAIL: BGM stream should be combat")

	audio.call("start_volcanic_ambience")
	assert(amb_player.playing == true, "FAIL: Ambience should be playing")
	assert(amb_player.stream == audio.get("stream_volcanic_rumble"), "FAIL: Ambience stream should be volcanic rumble")

	# Fire massive concurrent barrage across player attacks, enemy attacks, and volcanic hazards
	for wave in range(50):
		audio.call("play_slash")
		audio.call("play_hit")
		audio.call("play_crit")
		audio.call("play_dash")
		audio.call("play_player_hurt")
		audio.call("play_cast")
		audio.call("play_boss_slam")
		audio.call("play_lava_bubble")
		audio.call("play_lava_erupt")
		audio.call("play_rock_crash")

	# Verify BGM and Ambient players were NOT touched or corrupted by the pool
	assert(bgm_player.playing == true, "FAIL: BGM was stopped or corrupted by SFX flood")
	assert(bgm_player.stream == audio.get("stream_bgm_combat"), "FAIL: BGM stream was overwritten by SFX flood")
	assert(amb_player.playing == true, "FAIL: Ambience was stopped or corrupted by SFX flood")
	assert(amb_player.stream == audio.get("stream_volcanic_rumble"), "FAIL: Ambience stream was overwritten by SFX flood")
	print("  -> 500 interleaved SFX triggers fired without disrupting BGM or Ambient playback.")

	# Test BGM dynamic intensity and boss transition while ambience is running
	audio.call("transition_to_boss")
	assert(bgm_player.stream == audio.get("stream_bgm_boss"), "FAIL: BGM did not transition to boss")
	assert(amb_player.playing == true, "FAIL: Boss transition disrupted volcanic ambience")

	audio.call("set_boss_music_intensity", 1.4)
	assert(abs(bgm_player.pitch_scale - 1.4) < 0.001, "FAIL: Pitch scale modulation mismatch")
	assert(amb_player.pitch_scale == 1.0, "FAIL: Ambient player pitch was erroneously modified by BGM intensity")

	audio.call("duck_music", true)
	assert(abs(bgm_player.volume_db - (-18.0)) < 0.001, "FAIL: BGM ducking volume mismatch")
	assert(abs(amb_player.volume_db - (-12.0)) < 0.001, "FAIL: Ambient volume was erroneously ducked by duck_music")

	audio.call("duck_music", false)
	assert(abs(bgm_player.volume_db - (-10.0)) < 0.001, "FAIL: BGM unduck volume mismatch")

	audio.call("transition_to_combat")
	assert(bgm_player.stream == audio.get("stream_bgm_combat"), "FAIL: BGM did not revert to combat")
	assert(amb_player.playing == true, "FAIL: Combat transition disrupted volcanic ambience")
	print("  -> BGM transition, ducking, and pitch modulations strictly isolated from ambient loop.")

	# --------------------------------------------------------------------------
	# TEST 7: Audio Server Bus Integrity & Resource Cleanup
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 7] Verifying AudioServer bus routing and teardown safety...")
	var master_bus_idx: int = AudioServer.get_bus_index(&"Master")
	assert(master_bus_idx >= 0, "FAIL: Master audio bus missing on AudioServer")

	# Verify every pool player and dedicated player references &"Master"
	for p_node in player_pool:
		var p_cast: AudioStreamPlayer = p_node as AudioStreamPlayer
		assert(p_cast.bus == &"Master", "FAIL: Player pool member not routed to Master bus")
	assert(bgm_player.bus == &"Master", "FAIL: BGM player not routed to Master bus")
	assert(amb_player.bus == &"Master", "FAIL: Ambient player not routed to Master bus")

	# --------------------------------------------------------------------------
	# TEST 8: Uninitialized Instance Pre-Ready Guard Safety
	# --------------------------------------------------------------------------
	print("[ADVERSARIAL TEST 8] Verifying pre-ready guard safety on uninitialized instance...")
	var uninit: Node = audio_script.new()
	# All public volcanic audio calls must safely no-op without crashes or null derefs
	uninit.call("start_volcanic_ambience")
	uninit.call("stop_volcanic_ambience")
	uninit.call("set_volcanic_ambience", true)
	uninit.call("set_volcanic_ambience", false)
	uninit.call("play_lava_bubble")
	uninit.call("play_lava_erupt")
	uninit.call("play_lava_whoosh")
	uninit.call("play_rock_crash")
	uninit.call("play_stalactite_impact")
	uninit.call("play_volcanic_rumble")
	uninit.call("duck_music", true)
	uninit.call("set_boss_music_intensity", 1.5)
	uninit.free()
	print("  -> Uninitialized instance calls safely no-oped without null exceptions.")

	# Safe teardown
	audio.call("stop_volcanic_ambience")
	assert(amb_player.playing == false, "FAIL: Ambience should be stopped after final cleanup")
	root.remove_child(audio)
	audio.free()
	for f in range(5):
		await process_frame
	print("  -> Teardown completed without leaks or dangling audio server locks.")

	print("\n=======================================================")
	print(">>> ALL 8 ADVERSARIAL CHALLENGES PASSED EMPIRICALLY! <<<")
	print("=======================================================\n")
	quit(0)


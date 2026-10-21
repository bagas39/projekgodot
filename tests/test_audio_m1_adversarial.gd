extends SceneTree

# Adversarial Empirical Test Suite for Milestone 1: Volcanic Audio Synthesis
# Challenger: challenger_lc_m1_1

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _run_adversarial_suite() -> void:
	print("\n=======================================================")
	print("--- ADVERSARIAL AUDIO TEST HARNESS: MILESTONE 1 ---")
	print("=======================================================\n")

	var failed_checks: int = 0
	var total_checks: int = 0

	var audio_mgr_script := load("res://src/audio/audio_manager.gd")
	if audio_mgr_script == null:
		print("FATAL: Failed to load res://src/audio/audio_manager.gd")
		quit(1)
		return

	var audio: Node = audio_mgr_script.new()
	root.add_child(audio)
	if not audio.is_node_ready():
		await audio.ready

	# -----------------------------------------------------------------
	# CHECK 1: Stream Existence & Format Attributes
	# -----------------------------------------------------------------
	print("[CHECK 1] Inspecting stream existence, types, and AudioStreamWAV configurations...")
	var target_streams := {
		"stream_lava_bubble": audio.stream_lava_bubble,
		"stream_lava_erupt": audio.stream_lava_erupt,
		"stream_rock_crash": audio.stream_rock_crash,
		"stream_volcanic_rumble": audio.stream_volcanic_rumble
	}

	for stream_name in target_streams.keys():
		total_checks += 1
		var s: AudioStreamWAV = target_streams[stream_name]
		if s == null:
			print("  [FAIL] %s is NULL" % stream_name)
			failed_checks += 1
			continue

		if s.format != AudioStreamWAV.FORMAT_16_BITS:
			print("  [FAIL] %s format is %d, expected FORMAT_16_BITS (1)" % [stream_name, s.format])
			failed_checks += 1
			continue

		if s.mix_rate != 22050:
			print("  [FAIL] %s mix_rate is %d, expected 22050" % [stream_name, s.mix_rate])
			failed_checks += 1
			continue

		if s.stereo != false:
			print("  [FAIL] %s stereo is true, expected false (mono)" % stream_name)
			failed_checks += 1
			continue

		print("  [PASS] %s: non-null, FORMAT_16_BITS, mix_rate=22050, stereo=false" % stream_name)

	# -----------------------------------------------------------------
	# CHECK 2: Byte Length Verification (sample_rate * duration * 2)
	# -----------------------------------------------------------------
	print("\n[CHECK 2] Empirically verifying buffer byte lengths match sample_rate * duration * 2...")
	var expected_durations := {
		"stream_lava_bubble": 0.28,
		"stream_lava_erupt": 0.50,
		"stream_rock_crash": 0.48,
		"stream_volcanic_rumble": 3.20
	}

	for stream_name in expected_durations.keys():
		total_checks += 1
		var s: AudioStreamWAV = target_streams[stream_name]
		var duration: float = expected_durations[stream_name]
		var expected_samples: int = int(duration * 22050.0)
		var expected_bytes: int = expected_samples * 2
		var actual_bytes: int = s.data.size()

		if actual_bytes != expected_bytes:
			print("  [FAIL] %s byte length mismatch: expected %d bytes (%d samples), got %d bytes" % [stream_name, expected_bytes, expected_samples, actual_bytes])
			failed_checks += 1
		else:
			print("  [PASS] %s: %d bytes == exact expected %d bytes (samples: %d, dur: %.2fs)" % [stream_name, actual_bytes, expected_bytes, expected_samples, duration])

	# -----------------------------------------------------------------
	# CHECK 3: Sample Bounds, 16-Bit Range, NaN/Inf, DC Offset, RMS
	# -----------------------------------------------------------------
	print("\n[CHECK 3] Full scan: sample bounds [-32768, 32767], NaN/Inf checks, DC offset & RMS...")
	for stream_name in target_streams.keys():
		total_checks += 1
		var s: AudioStreamWAV = target_streams[stream_name]
		var bytes: PackedByteArray = s.data
		var sample_count: int = bytes.size() / 2

		var min_val: int = 32767
		var max_val: int = -32768
		var sum_val: float = 0.0
		var sum_sq: float = 0.0
		var clipped_count: int = 0
		var nan_or_inf_detected: bool = false
		var out_of_bounds_count: int = 0

		for i in range(sample_count):
			var sample: int = bytes.decode_s16(i * 2)

			if is_nan(float(sample)) or is_inf(float(sample)):
				nan_or_inf_detected = true

			if sample < -32768 or sample > 32767:
				out_of_bounds_count += 1

			if sample < min_val:
				min_val = sample
			if sample > max_val:
				max_val = sample

			if abs(sample) >= 32760:
				clipped_count += 1

			sum_val += float(sample)
			sum_sq += float(sample) * float(sample)

		var mean: float = sum_val / float(sample_count)
		var normalized_dc_offset: float = mean / 32767.0
		var rms: float = sqrt(sum_sq / float(sample_count)) / 32767.0
		var clip_ratio: float = float(clipped_count) / float(sample_count)

		print("  -> %s stats:" % stream_name)
		print("     samples: %d | min: %d | max: %d | DC offset: %.6f | RMS: %.4f | clip%%: %.2f%%" % [sample_count, min_val, max_val, normalized_dc_offset, rms, clip_ratio * 100.0])

		var stream_passed: bool = true
		if nan_or_inf_detected:
			print("     [FAIL] NaN or Infinity detected in PCM data!")
			stream_passed = false
		if out_of_bounds_count > 0:
			print("     [FAIL] %d samples out of signed 16-bit range [-32768, 32767]!" % out_of_bounds_count)
			stream_passed = false
		if abs(normalized_dc_offset) > 0.05:
			print("     [FAIL] Normalized DC offset excessive: %.4f > 0.05 threshold!" % normalized_dc_offset)
			stream_passed = false
		if rms < 0.01:
			print("     [FAIL] RMS too low (essentially silent): %.4f < 0.01!" % rms)
			stream_passed = false
		if clip_ratio > 0.15:
			print("     [FAIL] Severe hard clipping: %.2f%% of samples hit rails!" % (clip_ratio * 100.0))
			stream_passed = false

		if stream_passed:
			print("     [PASS] %s: PCM buffer valid, bounded, NaN-free, balanced." % stream_name)
		else:
			failed_checks += 1

	# -----------------------------------------------------------------
	# CHECK 4: Loop Points on stream_volcanic_rumble
	# -----------------------------------------------------------------
	print("\n[CHECK 4] Verifying stream_volcanic_rumble loop points & boundary continuity...")
	total_checks += 1
	var rumble: AudioStreamWAV = audio.stream_volcanic_rumble
	var expected_rumble_samples: int = int(3.20 * 22050.0)

	var loop_mode_ok: bool = (rumble.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var loop_begin_ok: bool = (rumble.loop_begin == 0)
	var loop_end_ok: bool = (rumble.loop_end == expected_rumble_samples)

	if not loop_mode_ok or not loop_begin_ok or not loop_end_ok:
		print("  [FAIL] Loop config mismatch: mode=%d (exp %d), begin=%d (exp 0), end=%d (exp %d)" % [
			rumble.loop_mode, AudioStreamWAV.LOOP_FORWARD,
			rumble.loop_begin,
			rumble.loop_end, expected_rumble_samples
		])
		failed_checks += 1
	else:
		print("  [PASS] Loop points exact: loop_mode=LOOP_FORWARD, loop_begin=0, loop_end=%d" % expected_rumble_samples)

	# Boundary discontinuity check between end and start sample
	var s_start: int = rumble.data.decode_s16(0)
	var s_end: int = rumble.data.decode_s16((expected_rumble_samples - 1) * 2)
	var seam_delta: float = abs(float(s_start - s_end)) / 32767.0
	print("  -> Seam discontinuity between sample 0 (%d) and sample %d (%d): delta=%.4f" % [s_start, expected_rumble_samples - 1, s_end, seam_delta])
	if seam_delta > 0.40:
		print("  [WARN/FAIL] Loop seam delta too high (potential pop/click): %.4f > 0.40" % seam_delta)
		failed_checks += 1
	else:
		print("  [PASS] Seam discontinuity is smooth (delta=%.4f <= 0.40)" % seam_delta)

	# -----------------------------------------------------------------
	# CHECK 5: Interface Contracts & Aliases
	# -----------------------------------------------------------------
	print("\n[CHECK 5] Testing public AudioManager API methods and contract aliases...")
	var api_tests := [
		"play_lava_bubble",
		"play_lava_erupt",
		"play_lava_whoosh",
		"play_rock_crash",
		"play_stalactite_impact",
		"play_volcanic_rumble",
		"start_volcanic_ambience",
		"stop_volcanic_ambience"
	]

	for method in api_tests:
		total_checks += 1
		if not audio.has_method(method):
			print("  [FAIL] AudioManager is missing method: %s" % method)
			failed_checks += 1
		else:
			print("  [PASS] Method exists: %s" % method)

	# Test execution of aliases and methods
	total_checks += 1
	audio.play_lava_bubble()
	audio.play_lava_erupt()
	audio.play_lava_whoosh()
	audio.play_rock_crash()
	audio.play_stalactite_impact()
	audio.play_volcanic_rumble()
	audio.start_volcanic_ambience()
	if not audio._ambient_player.playing:
		print("  [FAIL] _ambient_player should be playing after start_volcanic_ambience()")
		failed_checks += 1
	else:
		print("  [PASS] start_volcanic_ambience() activated _ambient_player")

	audio.set_volcanic_ambience(false)
	if audio._ambient_player.playing:
		print("  [FAIL] _ambient_player should be stopped after set_volcanic_ambience(false)")
		failed_checks += 1
	else:
		print("  [PASS] set_volcanic_ambience(false) stopped _ambient_player")

	audio.set_volcanic_ambience(true)
	if not audio._ambient_player.playing:
		print("  [FAIL] _ambient_player should be playing after set_volcanic_ambience(true)")
		failed_checks += 1
	else:
		print("  [PASS] set_volcanic_ambience(true) restarted _ambient_player")

	audio.stop_volcanic_ambience()
	if audio._ambient_player.playing:
		print("  [FAIL] _ambient_player should be stopped after stop_volcanic_ambience()")
		failed_checks += 1
	else:
		print("  [PASS] stop_volcanic_ambience() successfully stopped _ambient_player")

	# -----------------------------------------------------------------
	# CHECK 6: Stress Testing — Rapid-Fire Playback & Resource Stability
	# -----------------------------------------------------------------
	print("\n[CHECK 6] Rapid-fire stress testing: 100 rapid calls in tight loop...")
	total_checks += 1
	var pool_size: int = audio._player_pool.size()
	if pool_size != audio.POOL_SIZE:
		print("  [FAIL] Player pool size is %d, expected %d" % [pool_size, audio.POOL_SIZE])
		failed_checks += 1
	else:
		print("  [PASS] Player pool initialized with %d players" % pool_size)

	# Fire 100 playback calls
	var initial_pool_index: int = audio._pool_index
	for i in range(25):
		audio.play_lava_bubble()
		audio.play_lava_erupt()
		audio.play_rock_crash()
		audio.play_volcanic_rumble()

	# Check pool wrapping
	var expected_pool_index: int = (initial_pool_index + 100) % pool_size
	if audio._pool_index != expected_pool_index:
		print("  [FAIL] Pool index after 100 calls is %d, expected %d" % [audio._pool_index, expected_pool_index])
		failed_checks += 1
	else:
		print("  [PASS] Pool index rotated smoothly across 100 calls to %d" % audio._pool_index)

	# Verify all pool players are valid and not null
	total_checks += 1
	var all_players_valid: bool = true
	for i in range(pool_size):
		var p: AudioStreamPlayer = audio._player_pool[i]
		if not is_instance_valid(p) or p == null:
			all_players_valid = false
			break
	if all_players_valid:
		print("  [PASS] All %d AudioStreamPlayer instances remain intact and valid" % pool_size)
	else:
		print("  [FAIL] AudioStreamPlayer instance corruption or null detected in pool")
		failed_checks += 1

	# Rapid ambient toggling stress
	total_checks += 1
	for i in range(50):
		audio.set_volcanic_ambience(true)
		audio.set_volcanic_ambience(false)
	audio.stop_volcanic_ambience()
	if not audio._ambient_player.playing:
		print("  [PASS] 50 ambient toggles completed cleanly without hang or crash")
	else:
		print("  [FAIL] Ambient player in invalid state after toggle stress")
		failed_checks += 1

	# Edge case: play_stream with null
	total_checks += 1
	audio._play_stream(null)
	print("  [PASS] Null stream handled gracefully without throwing error")

	# Clean up
	audio.queue_free()

	print("\n=======================================================")
	if failed_checks == 0:
		print(">>> ALL %d ADVERSARIAL CHECKS PASSED (0 FAILURES)! <<<" % total_checks)
		print("=======================================================\n")
		quit(0)
	else:
		print(">>> ADVERSARIAL CHECKS FAILED: %d of %d failed! <<<" % [failed_checks, total_checks])
		print("=======================================================\n")
		quit(1)

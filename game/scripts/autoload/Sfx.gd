extends Node
## Autoload: the sound layer — a BONUS layer, never load-bearing (spec
## §7/§11: the iOS silent switch mutes Web Audio; every beat already lands
## visually). Architecture per §11: Sample playback only — every one-shot
## and loop is an AudioStreamWAV sample; NO AudioStreamGenerator, NO
## runtime bus effects (richness gets baked into samples offline). Music is
## depth-crossfaded by VOLUME (crossfade is playback, not a bus effect).
##
## PLACEHOLDER AUDIO: every sample below is synthesized in code at boot —
## cheap stand-ins that prove the playback architecture (pool, crossfade,
## unlock gesture). The real palette (jsfxr/ChipTone one-shots, Audacity
## foley dig thud, Bosca Ceoil looped-OGG ambient) replaces the generators
## by dropping files in and assigning them to the same names — nothing else
## moves. The tap-to-start tap is the audio-unlock gesture (spec §11):
## unlock() is called there and loops start only then.

const ONE_SHOT_RATE := 16000
const LOOP_RATE := 8000
const VOICE_COUNT := 8

var _samples := {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_next := 0
var _music: Array[AudioStreamPlayer] = []
var _hum: AudioStreamPlayer
var _unlocked := false
var _thrust := 0.0
var _hum_level := 0.0
## Fixed-seed RNG for noise in the placeholder synths — audio texture only,
## generated once at boot (worldgen determinism is untouched).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# One-shots must play inside the paused hub (sell/upgrade chimes).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 0x5F3759DF
	_build_samples()
	for i in range(VOICE_COUNT):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for key in ["ambient_surface", "ambient_mid", "ambient_deep"]:
		var m := AudioStreamPlayer.new()
		m.stream = _samples[key]
		m.volume_db = -60.0
		add_child(m)
		_music.append(m)
	_hum = AudioStreamPlayer.new()
	_hum.stream = _samples["hum"]
	_hum.volume_db = -60.0
	add_child(_hum)


func unlock() -> void:
	## Called by the tap-to-start tap — the Web Audio unlock gesture (spec
	## §11). Loops begin here; before this, play() stays silent by design.
	if _unlocked:
		return
	_unlocked = true
	for m in _music:
		m.play()
	_hum.play()


func play(sample_name: String, volume_db_offset: float = 0.0, pitch: float = 1.0) -> void:
	if not _unlocked or not _samples.has(sample_name):
		return
	var p := _voices[_voice_next % VOICE_COUNT]
	_voice_next += 1
	p.stream = _samples[sample_name]
	p.volume_db = Juice.config.sfx_volume_db + volume_db_offset
	p.pitch_scale = pitch
	p.play()


func set_thrust(intent_strength: float) -> void:
	## The engine-hum loop follows the stick (called by Player per tick).
	_thrust = clampf(intent_strength, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _unlocked:
		return
	var cfg: JuiceConfig = Juice.config
	# Depth-crossfaded ambient (spec §7/§11): triangle weights between the
	# anchor depths, applied as volume — playback, never a bus effect.
	var anchors := cfg.music_depth_anchors
	var depth := float(GameState.depth)
	for i in range(_music.size()):
		var w := _anchor_weight(depth, anchors, i)
		_music[i].volume_db = cfg.music_volume_db + linear_to_db(maxf(w, 0.001))
	_hum_level = lerpf(_hum_level, _thrust, minf(1.0, 8.0 * delta))
	_hum.volume_db = cfg.hum_volume_db + linear_to_db(maxf(_hum_level, 0.02))


func _anchor_weight(depth: float, anchors: PackedInt32Array, i: int) -> float:
	## Piecewise-linear triangle centred on anchors[i], reaching zero at the
	## neighbouring anchors; the edge anchors hold full weight outward.
	var here := float(anchors[i])
	if depth <= here:
		if i == 0:
			return 1.0
		var prev := float(anchors[i - 1])
		return clampf((depth - prev) / (here - prev), 0.0, 1.0)
	if i == anchors.size() - 1:
		return 1.0
	var next := float(anchors[i + 1])
	return clampf(1.0 - (depth - here) / (next - here), 0.0, 1.0)


# --- placeholder sample synthesis (stand-ins — see the header note) -------------


func _build_samples() -> void:
	# One-shots (~the 0008 §3.2 scoped palette).
	_samples["dig"] = _wav(_thump(0.09, 72.0, 30.0, 0.8), ONE_SHOT_RATE)
	_samples["break"] = _wav(_thump(0.16, 52.0, 16.0, 0.7), ONE_SHOT_RATE)
	_samples["hit"] = _wav(_thump(0.12, 110.0, 22.0, 1.1), ONE_SHOT_RATE)
	_samples["gas"] = _wav(_tone(0.3, [], 0.5, 12.0, 1.0), ONE_SHOT_RATE)
	_samples["rumble"] = _wav(_tone(0.5, [48.0, 55.0], 0.9, 6.0, 0.5), ONE_SHOT_RATE)
	_samples["gem"] = _wav(_tone(0.18, [1046.5, 1568.0], 0.4, 14.0), ONE_SHOT_RATE)
	_samples["prize"] = _wav(
		_seq(
			[
				_tone(0.12, [784.0], 0.4, 8.0),
				_tone(0.12, [988.0], 0.4, 8.0),
				_tone(0.4, [1318.5, 1976.0], 0.35, 6.0),
			]
		),
		ONE_SHOT_RATE
	)
	_samples["sell"] = _wav(
		_seq([_tone(0.08, [988.0], 0.4, 10.0), _tone(0.22, [1318.5], 0.4, 9.0)]), ONE_SHOT_RATE
	)
	_samples["upgrade"] = _wav(_tone(0.25, [659.3, 880.0], 0.45, 9.0), ONE_SHOT_RATE)
	_samples["milestone"] = _wav(
		_seq([_tone(0.15, [587.3], 0.4, 7.0), _tone(0.3, [880.0, 1108.7], 0.4, 6.0)]), ONE_SHOT_RATE
	)
	_samples["warning"] = _wav(
		_seq([_tone(0.09, [660.0], 0.35, 6.0), _silence(0.05), _tone(0.09, [660.0], 0.35, 6.0)]),
		ONE_SHOT_RATE
	)
	_samples["lost"] = _wav(_fall_sting(0.7), ONE_SHOT_RATE)
	_samples["click"] = _wav(_tone(0.03, [2000.0], 0.3, 60.0, 0.3), ONE_SHOT_RATE)
	# Loops: 3 depth-crossfaded ambient drones + the engine hum. Placeholder
	# WAV loops; the real ones ship as looped OGG (spec §11).
	_samples["ambient_surface"] = _wav(
		_loop_chord(4.0, [220.0, 277.2, 330.0], 0.12, 0.0), LOOP_RATE, true
	)
	_samples["ambient_mid"] = _wav(
		_loop_chord(4.0, [146.8, 174.6, 220.0], 0.12, 0.01), LOOP_RATE, true
	)
	_samples["ambient_deep"] = _wav(
		_loop_chord(4.0, [55.0, 65.4, 87.3], 0.16, 0.025), LOOP_RATE, true
	)
	_samples["hum"] = _wav(_loop_chord(0.5, [55.0, 110.0], 0.4, 0.06), LOOP_RATE, true)


func _wav(frames: PackedFloat32Array, rate: int, looped: bool = false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(frames.size() * 2)
	for i in range(frames.size()):
		pcm.encode_s16(i * 2, int(clampf(frames[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames.size()
	return wav


func _tone(
	dur: float, freqs: Array, amp: float, decay: float, noise_amp: float = 0.0
) -> PackedFloat32Array:
	## Additive sines + optional noise under an exponential decay envelope.
	var n := int(dur * ONE_SHOT_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / ONE_SHOT_RATE
		var s := 0.0
		for f: float in freqs:
			s += sin(TAU * f * t)
		if not freqs.is_empty():
			s /= float(freqs.size())
		if noise_amp > 0.0:
			s += (_rng.randf() * 2.0 - 1.0) * noise_amp
		buf[i] = s * amp * exp(-decay * t)
	return buf


func _thump(dur: float, freq: float, decay: float, noise_amp: float) -> PackedFloat32Array:
	## The dig-thud family: a low sine with a pitch drop + noisy attack —
	## the foley stand-in (the real dig thud is recorded, spec §7).
	var n := int(dur * ONE_SHOT_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / ONE_SHOT_RATE
		var env := exp(-decay * t)
		var s := sin(TAU * freq * (1.0 - t * 2.0) * t)
		s += (_rng.randf() * 2.0 - 1.0) * noise_amp * exp(-decay * 2.0 * t)
		buf[i] = s * 0.9 * env
	return buf


func _fall_sting(dur: float) -> PackedFloat32Array:
	## Run lost: a slow descending detuned slide — terse, minor, done.
	var n := int(dur * ONE_SHOT_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase_a := 0.0
	var phase_b := 0.0
	for i in range(n):
		var t := float(i) / ONE_SHOT_RATE
		var f := lerpf(392.0, 196.0, t / dur)
		phase_a += TAU * f / ONE_SHOT_RATE
		phase_b += TAU * f * 1.007 / ONE_SHOT_RATE
		buf[i] = (sin(phase_a) + sin(phase_b)) * 0.24 * exp(-3.2 * t)
	return buf


func _silence(dur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * ONE_SHOT_RATE))
	return buf


func _seq(parts: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		buf.append_array(part)
	return buf


func _loop_chord(dur: float, freqs: Array, amp: float, noise_amp: float) -> PackedFloat32Array:
	## A seamless drone loop: every oscillator (and the slow swell) is
	## quantized to whole cycles over the loop, so frame n wraps to frame 0.
	var n := int(dur * LOOP_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / LOOP_RATE
		var s := 0.0
		for f: float in freqs:
			var fq := roundf(f * dur) / dur  # whole cycles per loop
			s += sin(TAU * fq * t)
		s /= float(maxi(1, freqs.size()))
		var swell := 0.85 + 0.15 * sin(TAU * t / dur)
		if noise_amp > 0.0:
			s += (_rng.randf() * 2.0 - 1.0) * noise_amp
		buf[i] = s * amp * swell
	return buf

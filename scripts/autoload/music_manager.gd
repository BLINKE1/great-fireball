extends Node

const SR        = 22050
const LOOP_SECS = 12
const N         = SR * LOOP_SECS

var _player: AudioStreamPlayer = null
var _streams: Dictionary       = {}
var _current: String           = ""
var _thread: Thread            = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -9.0
	add_child(_player)
	_thread = Thread.new()
	_thread.start(_build_threaded)

func _build_threaded() -> void:
	_streams["menu"] = _gen_menu()
	_streams["game"] = _gen_game()
	_streams["boss"] = _gen_boss()
	call_deferred("_on_built")

func _on_built() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _current != "" and not _player.playing:
		var s: AudioStreamWAV = _streams.get(_current)
		if s:
			_player.stream = s
			_player.play()

func play(track: String) -> void:
	if _current == track and _player.playing: return
	_current = track
	var s: AudioStreamWAV = _streams.get(track)
	if not s: return
	if _player.playing:
		var tw := create_tween()
		tw.tween_property(_player, "volume_db", -50.0, 0.50)
		tw.tween_callback(func():
			_player.stream = s
			_player.volume_db = -50.0
			_player.play()
			_player.create_tween().tween_property(_player, "volume_db", -9.0, 0.65)
		)
	else:
		_player.stream = s
		_player.play()

func stop() -> void:
	_player.stop()
	_current = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _thread != null and _thread.is_started():
			_thread.wait_to_finish()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _note(t: float, start: float, dur: float, freq: float, amp: float) -> float:
	var r := t - start
	if r < 0.0 or r >= dur: return 0.0
	return sin(TAU * freq * t) * sin(PI * r / dur) * amp

func _note2(t: float, start: float, dur: float, freq: float, amp: float) -> float:
	var r := t - start
	if r < 0.0 or r >= dur: return 0.0
	# Slightly detuned second harmonic for warmth
	return (sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 1.004 * t) * 0.3) \
			* sin(PI * r / dur) * amp

# ── Menu Track — C major, warm and mystical (12 seconds) ─────────────────────

func _gen_menu() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(N * 2)
	for i in N:
		var t := float(i) / SR
		var s := 0.0

		# Bass drone: C2 + G2 (fifth)
		var am := 0.60 + 0.40 * sin(TAU * 0.20 * t)
		s += sin(TAU * 65.0  * t) * 0.180 * am
		s += sin(TAU * 98.0  * t) * 0.075 * am   # G2 — fifth
		s += sin(TAU * 130.0 * t) * 0.090 * am

		# Warm major pad: C4-E4-G4-B4 (Cmaj7)
		s += sin(TAU * 261.0 * t) * 0.055
		s += sin(TAU * 329.0 * t) * 0.044
		s += sin(TAU * 392.0 * t) * 0.036
		s += sin(TAU * 493.0 * t) * 0.022   # B4 adds warmth

		# Shimmering A4 pulse
		s += sin(TAU * 440.0 * t) * 0.022 * (0.5 + 0.5 * sin(TAU * 0.38 * t))

		# High C6 shimmer (fairy dust)
		s += sin(TAU * 1046.0 * t) * 0.012 * (0.4 + 0.6 * sin(TAU * 0.55 * t))

		# Melody line (8 notes over 12 seconds)
		s += _note(t,  1.0, 0.90, 523.0, 0.082)   # C5
		s += _note(t,  2.5, 0.75, 440.0, 0.070)   # A4
		s += _note(t,  3.8, 0.85, 392.0, 0.075)   # G4
		s += _note(t,  5.2, 0.72, 329.0, 0.065)   # E4
		s += _note(t,  6.5, 0.90, 523.0, 0.078)   # C5 (return)
		s += _note(t,  8.0, 0.75, 587.0, 0.068)   # D5
		s += _note(t,  9.4, 0.85, 523.0, 0.072)   # C5
		s += _note(t, 11.0, 0.78, 392.0, 0.060)   # G4 → leading to loop

		# Countermelody (softer, lower octave)
		s += _note(t,  2.0, 0.55, 329.0, 0.032)   # E4
		s += _note(t,  4.8, 0.55, 261.0, 0.030)   # C4
		s += _note(t,  7.2, 0.55, 293.0, 0.028)   # D4
		s += _note(t, 10.2, 0.55, 261.0, 0.026)   # C4

		var pcm := int(clamp(s, -1.0, 1.0) * 25000)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_stream(data)

# ── Game Track — A minor, tense and adventurous (12 seconds) ─────────────────

func _gen_game() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(N * 2)
	for i in N:
		var t := float(i) / SR
		var s := 0.0

		# Deep bass: A1-E2-A2 (power chord with fifth)
		var am := 0.65 + 0.35 * sin(TAU * 0.17 * t)
		s += sin(TAU * 55.0  * t) * 0.210 * am
		s += sin(TAU * 82.0  * t) * 0.085 * am   # E2 — fifth
		s += sin(TAU * 110.0 * t) * 0.115 * am

		# Am pad: A3-C4-E4
		s += sin(TAU * 220.0 * t) * 0.050
		s += sin(TAU * 261.0 * t) * 0.040
		s += sin(TAU * 329.0 * t) * 0.032

		# Tension pulse: Bb4 (tritone dissonance)
		s += sin(TAU * 466.0 * t) * 0.016 * (0.5 + 0.5 * sin(TAU * 0.26 * t))

		# Walking bass line (subtle arpeggio: A2-C3-E3-G3 cycling every 3s)
		var bass_cycle := fmod(t, 3.0)
		if bass_cycle < 0.75:
			s += sin(TAU * 110.0 * t) * 0.025 * (0.5 + 0.5 * sin(TAU * bass_cycle / 0.75))
		elif bass_cycle < 1.5:
			s += sin(TAU * 130.0 * t) * 0.022 * (0.5 + 0.5 * sin(TAU * (bass_cycle - 0.75) / 0.75))
		elif bass_cycle < 2.25:
			s += sin(TAU * 164.0 * t) * 0.020 * (0.5 + 0.5 * sin(TAU * (bass_cycle - 1.5) / 0.75))
		else:
			s += sin(TAU * 196.0 * t) * 0.018 * (0.5 + 0.5 * sin(TAU * (bass_cycle - 2.25) / 0.75))

		# Melody (8 notes, adventurous minor feel)
		s += _note(t,  0.8, 0.72, 329.0, 0.075)   # E4
		s += _note(t,  2.4, 0.65, 440.0, 0.068)   # A4
		s += _note(t,  3.8, 0.72, 392.0, 0.062)   # G4
		s += _note(t,  5.2, 0.60, 523.0, 0.058)   # C5 (reaches up)
		s += _note(t,  6.8, 0.68, 294.0, 0.070)   # D4
		s += _note(t,  8.2, 0.78, 220.0, 0.075)   # A3 (descent)
		s += _note(t,  9.8, 0.72, 329.0, 0.065)   # E4 (re-establish)
		s += _note(t, 11.2, 0.62, 392.0, 0.055)   # G4 (→ loop)

		# Countermelody (second voice)
		s += _note(t,  1.6, 0.50, 261.0, 0.030)   # C4
		s += _note(t,  4.5, 0.50, 329.0, 0.028)   # E4
		s += _note(t,  7.5, 0.50, 293.0, 0.026)   # D4
		s += _note(t, 10.5, 0.50, 261.0, 0.024)   # C4

		var pcm := int(clamp(s, -1.0, 1.0) * 25000)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_stream(data)

# ── Boss Track — A minor, intense, rhythmic (12 seconds) ──────────────────────

func _gen_boss() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345   # deterministic so the loop sounds consistent
	var data := PackedByteArray()
	data.resize(N * 2)
	for i in N:
		var t := float(i) / SR
		var s := 0.0

		# Aggressive bass with fast AM
		var am := 0.50 + 0.50 * sin(TAU * 0.33 * t)
		s += sin(TAU * 55.0  * t) * 0.240 * am
		s += sin(TAU * 82.0  * t) * 0.095 * am
		s += sin(TAU * 110.0 * t) * 0.135 * am

		# Driving rhythm: kick drum every 0.75s (16 beats per 12s)
		var beat := fmod(t, 0.75)
		if beat < 0.10:
			var bp := beat / 0.10
			s += sin(TAU * 55.0 * t) * (1.0 - bp) * (1.0 - bp) * 0.22

		# Snare hit on beats 2 & 4 (every 0.75s, offset by 0.375)
		var beat2 := fmod(t + 0.375, 0.75)
		if beat2 < 0.06:
			var bp2 := beat2 / 0.06
			var snare_rng := RandomNumberGenerator.new()
			snare_rng.seed = i
			s += snare_rng.randf_range(-0.7, 0.7) * (1.0 - bp2) * 0.075

		# Tense minor chord: Am7 (A-C-E-G)
		s += sin(TAU * 220.0 * t) * 0.044
		s += sin(TAU * 261.0 * t) * 0.036
		s += sin(TAU * 329.0 * t) * 0.030
		s += sin(TAU * 392.0 * t) * 0.022

		# Dissonance: Bb4 + F#4 (diminished tension)
		s += sin(TAU * 466.0 * t) * 0.024 * (0.5 + 0.5 * sin(TAU * 0.44 * t))
		s += sin(TAU * 370.0 * t) * 0.016 * (0.5 + 0.5 * sin(TAU * 0.58 * t))

		# Riff: A3-G3-F3-E3 repeating power riff (every 3s)
		var riff := fmod(t, 3.0)
		if riff < 0.62:
			s += sin(TAU * 220.0 * t) * sin(PI * riff / 0.62) * 0.038
		elif riff < 1.22:
			s += sin(TAU * 196.0 * t) * sin(PI * (riff - 0.62) / 0.60) * 0.035
		elif riff < 1.80:
			s += sin(TAU * 174.0 * t) * sin(PI * (riff - 1.22) / 0.58) * 0.032
		elif riff < 2.38:
			s += sin(TAU * 164.0 * t) * sin(PI * (riff - 1.80) / 0.58) * 0.030

		# Urgent ascending melody (8 notes)
		s += _note(t,  0.6, 0.40, 440.0, 0.060)   # A4
		s += _note(t,  1.4, 0.36, 523.0, 0.055)   # C5
		s += _note(t,  2.4, 0.38, 466.0, 0.048)   # Bb4 (tension)
		s += _note(t,  3.4, 0.42, 440.0, 0.058)   # A4 (release)
		s += _note(t,  4.6, 0.36, 329.0, 0.052)   # E4
		s += _note(t,  5.8, 0.40, 392.0, 0.050)   # G4
		s += _note(t,  7.2, 0.44, 440.0, 0.062)   # A4 (climax approach)
		s += _note(t,  8.4, 0.38, 523.0, 0.056)   # C5 (peak)
		s += _note(t,  9.6, 0.40, 466.0, 0.046)   # Bb4
		s += _note(t, 10.8, 0.38, 440.0, 0.055)   # A4 (→ loop)

		var pcm := int(clamp(s, -1.0, 1.0) * 25000)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_stream(data)

# ─────────────────────────────────────────────────────────────────────────────

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format     = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo     = false
	stream.mix_rate   = SR
	stream.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end   = N
	stream.data       = data
	return stream

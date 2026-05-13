extends Node

const SR        = 22050
const LOOP_SECS = 6
const N         = SR * LOOP_SECS   # 132300 samples

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
	if not s: return   # _on_built() will pick up _current and start then
	if _player.playing:
		# Crossfade: fade out, swap, fade in
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

# ── Menu Track — C major, warm and mysterious ─────────────────────────────────

func _gen_menu() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(N * 2)
	for i in N:
		var t := float(i) / SR
		var s := 0.0
		# Bass drone (C2 + C3) with gentle amplitude modulation
		var am := 0.65 + 0.35 * sin(TAU * 0.22 * t)
		s += sin(TAU * 65.0  * t) * 0.200 * am
		s += sin(TAU * 130.0 * t) * 0.100 * am
		# Warm major pad (C-E-G) — always present
		s += sin(TAU * 261.0 * t) * 0.062
		s += sin(TAU * 329.0 * t) * 0.048
		s += sin(TAU * 392.0 * t) * 0.040
		# Shimmering A4 — gentle pulse
		s += sin(TAU * 440.0 * t) * 0.028 * (0.5 + 0.5 * sin(TAU * 0.40 * t))
		# Melody note 1: C5 at t=1.2, dur=0.95
		var r1 := t - 1.2
		if r1 >= 0.0 and r1 < 0.95:
			s += sin(TAU * 523.0 * t) * sin(PI * r1 / 0.95) * 0.085
		# Melody note 2: G4 at t=3.5, dur=0.85
		var r2 := t - 3.5
		if r2 >= 0.0 and r2 < 0.85:
			s += sin(TAU * 392.0 * t) * sin(PI * r2 / 0.85) * 0.072
		# Melody note 3: E4 at t=5.2, dur=0.72
		var r3 := t - 5.2
		if r3 >= 0.0 and r3 < 0.72:
			s += sin(TAU * 329.0 * t) * sin(PI * r3 / 0.72) * 0.062
		var pcm := int(clamp(s, -1.0, 1.0) * 25000)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_stream(data)

# ── Game Track — A minor, tense and adventurous ───────────────────────────────

func _gen_game() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(N * 2)
	for i in N:
		var t := float(i) / SR
		var s := 0.0
		# Deep bass (A1 + E2 fifth + A2) — ominous feel
		var am := 0.68 + 0.32 * sin(TAU * 0.18 * t)
		s += sin(TAU * 55.0  * t) * 0.220 * am
		s += sin(TAU * 82.0  * t) * 0.090 * am   # E2 — the fifth
		s += sin(TAU * 110.0 * t) * 0.120 * am
		# Minor pad (A-C-E)
		s += sin(TAU * 220.0 * t) * 0.055
		s += sin(TAU * 261.0 * t) * 0.044
		s += sin(TAU * 329.0 * t) * 0.036
		# Unsettled high Bb pulse (tension)
		s += sin(TAU * 466.0 * t) * 0.018 * (0.5 + 0.5 * sin(TAU * 0.28 * t))
		# Melody note 1: E4 at t=1.2, dur=0.72
		var r1 := t - 1.2
		if r1 >= 0.0 and r1 < 0.72:
			s += sin(TAU * 329.0 * t) * sin(PI * r1 / 0.72) * 0.078
		# Melody note 2: A4 at t=3.1, dur=0.65
		var r2 := t - 3.1
		if r2 >= 0.0 and r2 < 0.65:
			s += sin(TAU * 440.0 * t) * sin(PI * r2 / 0.65) * 0.068
		# Melody note 3: G4 at t=4.8, dur=0.72
		var r3 := t - 4.8
		if r3 >= 0.0 and r3 < 0.72:
			s += sin(TAU * 392.0 * t) * sin(PI * r3 / 0.72) * 0.062
		var pcm := int(clamp(s, -1.0, 1.0) * 25000)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_stream(data)

# ── Boss Track — A minor, intense with rhythmic bass thumps ──────────────────

func _gen_boss() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(N * 2)
	for i in N:
		var t := float(i) / SR
		var s := 0.0
		# Aggressive bass with fast AM (0.35 Hz)
		var am := 0.55 + 0.45 * sin(TAU * 0.35 * t)
		s += sin(TAU * 55.0  * t) * 0.250 * am
		s += sin(TAU * 82.0  * t) * 0.100 * am
		s += sin(TAU * 110.0 * t) * 0.140 * am
		# Rhythmic thump every 1.5s (4 beats per 6-second loop)
		var beat := fmod(t, 1.5)
		if beat < 0.12:
			s += sin(TAU * 55.0 * t) * (1.0 - beat / 0.12) * 0.18
		# Tense minor chord + minor 7th (A-C-E-G)
		s += sin(TAU * 220.0 * t) * 0.048
		s += sin(TAU * 261.0 * t) * 0.038
		s += sin(TAU * 329.0 * t) * 0.032
		s += sin(TAU * 392.0 * t) * 0.024
		# Bb4 dissonance pulse — constant tension
		s += sin(TAU * 466.0 * t) * 0.026 * (0.5 + 0.5 * sin(TAU * 0.45 * t))
		# Urgent ascending melody
		var r1 := t - 0.8
		if r1 >= 0.0 and r1 < 0.42: s += sin(TAU * 440.0 * t) * sin(PI * r1 / 0.42) * 0.062
		var r2 := t - 1.5
		if r2 >= 0.0 and r2 < 0.35: s += sin(TAU * 523.0 * t) * sin(PI * r2 / 0.35) * 0.055
		var r3 := t - 2.6
		if r3 >= 0.0 and r3 < 0.38: s += sin(TAU * 466.0 * t) * sin(PI * r3 / 0.38) * 0.048
		var r4 := t - 3.5
		if r4 >= 0.0 and r4 < 0.42: s += sin(TAU * 440.0 * t) * sin(PI * r4 / 0.42) * 0.058
		var r5 := t - 4.8
		if r5 >= 0.0 and r5 < 0.35: s += sin(TAU * 329.0 * t) * sin(PI * r5 / 0.35) * 0.052
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

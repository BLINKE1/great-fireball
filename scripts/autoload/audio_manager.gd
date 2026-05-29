extends Node

const SAMPLE_RATE = 22050
const POOL_SIZE = 12

# Authored audio overrides: drop a file named <key>.ogg or <key>.wav into
# assets/audio/ and it replaces the procedural synth for that sound.
const _AUDIO_DIR := "res://assets/audio/"
const _AUDIO_EXTS := ["ogg", "wav"]

var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}  # key -> AudioStream (authored) or null (use procedural)

func _ready() -> void:
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

func play(sound: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = _get_stream(sound)
	if not stream:
		return
	var player := _free_player()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()

func _get_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		var cached = _cache[sound]
		return cached if cached != null else _build(sound)
	# Try authored file first
	for ext: String in _AUDIO_EXTS:
		var path: String = _AUDIO_DIR + sound + "." + ext
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is AudioStream:
				_cache[sound] = res
				return res
		elif FileAccess.file_exists(path):
			var stream := _load_raw(path, ext)
			if stream:
				_cache[sound] = stream
				return stream
	# Fall back to procedural synth
	_cache[sound] = null
	return _build(sound)

func _load_raw(path: String, ext: String) -> AudioStream:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		return null
	if ext == "wav":
		var s := AudioStreamWAV.new()
		# Parse minimal WAV header to extract PCM data and format
		if data.size() > 44 and data.slice(0, 4) == "RIFF".to_ascii_buffer():
			var channels: int  = data[22] | (data[23] << 8)
			var rate: int      = data[24] | (data[25] << 8) | (data[26] << 16) | (data[27] << 24)
			var bits: int      = data[34] | (data[35] << 8)
			var pcm_start: int = 44
			# Locate "data" chunk in case there are extra chunks
			for i in range(36, min(data.size() - 8, 200)):
				if data[i] == 100 and data[i+1] == 97 and data[i+2] == 116 and data[i+3] == 97:
					pcm_start = i + 8; break
			s.data      = data.slice(pcm_start)
			s.mix_rate  = rate
			s.stereo    = (channels == 2)
			s.format    = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
			return s
	elif ext == "ogg":
		var s := AudioStreamOggVorbis.load_from_buffer(data)
		return s
	return null

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]

func _build(sound: String) -> AudioStreamWAV:
	match sound:
		"jump":         return _wave(380.0, 0.09, "up",        0.50)
		"land":         return _wave(100.0, 0.07, "thud",      0.45)
		"sword":        return _wave(280.0, 0.11, "noise",     0.60)
		"hit":          return _wave(220.0, 0.09, "noise",     0.55)
		"hit_player":   return _wave(140.0, 0.22, "thud",      0.80)
		"cast":         return _wave(560.0, 0.14, "down",      0.40)
		"missile":      return _wave(480.0, 0.09, "up",        0.38)
		"time_stop":    return _wave(820.0, 0.32, "down",      0.35)
		"heal":         return _wave(540.0, 0.28, "chord",     0.38)
		"dash":         return _wave(520.0, 0.09, "up",        0.25)
		"die":          return _wave(90.0,  0.55, "thud",      0.85)
		"enemy_die":    return _wave(180.0, 0.35, "thud",      0.55)
		"unlock":       return _wave(660.0, 0.45, "chord",     0.48)
		"chest":        return _wave(440.0, 0.30, "chord",     0.42)
		"fireball":     return _wave(110.0, 0.90, "explosion", 0.92)
		"arrow":        return _wave(340.0, 0.07, "noise",     0.32)
		"orb_pickup":   return _wave(720.0, 0.22, "chord",     0.30)
		"stomp":        return _wave(55.0,  0.40, "thud",      0.90)
		"boss_appear":  return _wave(72.0,  0.85, "explosion", 0.88)
		"double_jump":  return _wave(480.0, 0.12, "chord",     0.28)
		"detect":       return _wave(1050.0, 0.12, "up",       0.20)
		"tick":         return _wave(640.0,  0.025,"up",       0.09)
		"no_mana":      return _wave(110.0,  0.14, "thud",     0.22)
		"step":         return _wave(160.0,  0.055,"thud",     0.18)
		"enemy_attack": return _wave(220.0,  0.10, "noise",    0.32)
		"roar":               return _wave(55.0,   0.55, "explosion", 0.78)
		"victory":            return _wave(392.0,  1.10, "chord",     0.72)
		"missile_spread":     return _wave(540.0,  0.11, "chord",     0.42)
		"missile_piercing":   return _wave(680.0,  0.08, "up",        0.35)
		"missile_giant":      return _wave(180.0,  0.55, "explosion", 0.75)
		"missile_giant_hit":  return _wave(95.0,   0.70, "explosion", 0.90)
		"missile_curved":     return _wave(620.0,  0.13, "spiral",    0.38)
		"heartbeat":          return _wave(52.0,   0.22, "heartbeat", 0.42)
		"skill_use":          return _wave(440.0,  0.10, "up",        0.22)
		"shield_activate":    return _wave(780.0,  0.28, "chord",     0.44)
		"shield_hit":         return _wave(320.0,  0.18, "thud",      0.55)
		"shield_break":       return _wave(160.0,  0.40, "explosion", 0.60)
		"burn":               return _wave(280.0,  0.55, "noise",     0.28)
		"fire_arrow":         return _wave(480.0,  0.08, "up",        0.30)
		"stone_emerge":       return _wave(72.0,   0.75, "explosion", 0.78)
		"qte_alert":          return _wave(920.0,  0.18, "down",      0.50)
	return null

func _wave(freq: float, dur: float, shape: String, vol: float) -> AudioStreamWAV:
	var n = int(SAMPLE_RATE * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var p: float = float(i) / n
		var env := pow(1.0 - p, 0.6)
		var s  := 0.0
		match shape:
			"up":
				var f = freq * (1.0 + p * 1.5)
				s = sin(TAU * f * t)
			"down":
				var f = freq * (2.5 - p * 1.5)
				s = sin(TAU * f * t)
			"thud":
				var f = freq * (1.0 - p * 0.75)
				s = sin(TAU * f * t)
				env = pow(1.0 - p, 1.8)
			"noise":
				s = rng.randf_range(-1.0, 1.0)
				env = pow(1.0 - p, 1.5)
			"chord":
				s = sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 1.25 * t) * 0.3 + sin(TAU * freq * 1.5 * t) * 0.2
				env = 1.0 - p * 0.65
			"spiral":
				var f = freq * (1.0 + sin(p * TAU * 2.0) * 0.25)
				s = sin(TAU * f * t) * 0.60 + sin(TAU * f * 1.50 * t) * 0.40
				env = pow(1.0 - p, 0.5)
			"heartbeat":
				# Lub-dub: first thump at t=0, second at t=0.10
				var lub := pow(maxf(1.0 - p / 0.35, 0.0), 2.2)
				var dub_t := t - 0.10
				var dub := 0.0
				if dub_t >= 0.0:
					var dp := dub_t / (dur - 0.10)
					dub = pow(maxf(1.0 - dp / 0.38, 0.0), 2.0) * 0.65
				s = sin(TAU * freq * t) * (lub + dub)
				env = 1.0
			"explosion":
				var f = freq * (1.0 - p * 0.5)
				s = sin(TAU * f * t) * 0.35 + rng.randf_range(-0.65, 0.65)
				env = pow(1.0 - p, 0.75)
		var pcm = int(clamp(s * env * vol, -1.0, 1.0) * 32767)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream

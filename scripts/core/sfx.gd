extends Node
## Autoload "Sfx". Original procedurally generated placeholder sounds (no
## recordings, no recognizable music). Replace with approved assets later;
## see docs/ASSET_APPROVALS.md. Important sounds also raise a subtitle via
## the `subtitle` signal when subtitles are enabled.

signal subtitle(text: String)

const RATE := 22050
var _cache: Dictionary = {}
var _players: Array = []
var _music: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

const SUBTITLES: Dictionary = {
	"laugh": "[audience laughter]",
	"big_laugh": "[big laughter]",
	"applause": "[applause]",
	"groan": "[audience groans]",
	"silence": "[silence... a glass clinks]",
	"sting": "[band sting]",
	"playoff": "[the band plays you off]",
}


func _ready() -> void:
	_rng.seed = 1234
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)


func play(id: String) -> void:
	var stream := _stream_for(id)
	if stream == null:
		return
	for p in _players:
		var ap: AudioStreamPlayer = p
		if not ap.playing:
			ap.stream = stream
			ap.play()
			break
	if SUBTITLES.has(id) and bool(GameSettings.values.get("subtitles", true)):
		subtitle.emit(str(SUBTITLES[id]))


func play_music(id: String) -> void:
	var stream := _stream_for(id)
	if stream == null:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func _stream_for(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var samples := PackedFloat32Array()
	match id:
		"click":
			samples = _tone(880.0, 0.05, 0.25)
		"confirm":
			samples = _tone(660.0, 0.06, 0.25) + _tone(990.0, 0.08, 0.25)
		"laugh":
			samples = _crowd(0.9, 6.0, 0.35)
		"big_laugh":
			samples = _crowd(1.6, 5.0, 0.55)
		"applause":
			samples = _crowd(2.2, 18.0, 0.5)
		"groan":
			samples = _tone(140.0, 0.6, 0.3)
		"silence":
			samples = _tone(2400.0, 0.04, 0.12)
		"sting":
			samples = _chord([220.0, 277.2, 329.6], 0.7, 0.3)
		"playoff":
			samples = _chord([196.0, 246.9, 293.7], 0.4, 0.3) + _chord([220.0, 277.2, 329.6], 0.8, 0.3)
		"street_loop":
			samples = _crowd(4.0, 1.5, 0.05)
		"band_loop":
			samples = _bass_loop()
		_:
			return null
	var wav := _to_wav(samples, id.ends_with("_loop"))
	_cache[id] = wav
	return wav


func _tone(freq: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var env := minf(1.0, t * 80.0) * (1.0 - float(i) / n)
		out[i] = sin(TAU * freq * t) * amp * env
	return out


func _chord(freqs: Array, dur: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t) + 0.3 * sin(TAU * float(f) * 2.0 * t)
		out[i] = v / freqs.size() * amp * (1.0 - float(i) / n)
	return out


## Filtered noise with a burst envelope: a rough, original crowd texture.
func _crowd(dur: float, bursts: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / RATE
		lp = lp * 0.82 + _rng.randf_range(-1.0, 1.0) * 0.18
		var env := (0.6 + 0.4 * sin(TAU * bursts * t)) * minf(1.0, t * 10.0) * minf(1.0, (dur - t) * 3.0)
		out[i] = lp * amp * env * 2.5
	return out


func _bass_loop() -> PackedFloat32Array:
	var notes := [110.0, 110.0, 146.8, 130.8, 110.0, 164.8, 146.8, 123.5]
	var out := PackedFloat32Array()
	for f in notes:
		out.append_array(_tone(float(f), 0.25, 0.35))
	return out


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav

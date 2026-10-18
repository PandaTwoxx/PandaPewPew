extends Node
## Procedural UI audio synthesizer for PandaPewPew.
## Generates lightweight 16-bit PCM retro-modern sound effects on the fly.

static var sound_enabled: bool = true

var _player_hover: AudioStreamPlayer
var _player_click: AudioStreamPlayer
var _player_alert: AudioStreamPlayer


func _ready() -> void:
	_player_hover = AudioStreamPlayer.new()
	_player_hover.stream = _create_hover_sound()
	_player_hover.volume_db = -10.0
	add_child(_player_hover)

	_player_click = AudioStreamPlayer.new()
	_player_click.stream = _create_pew_sound()
	_player_click.volume_db = -6.0
	add_child(_player_click)

	_player_alert = AudioStreamPlayer.new()
	_player_alert.stream = _create_alert_sound()
	_player_alert.volume_db = -8.0
	add_child(_player_alert)


func play_hover() -> void:
	if sound_enabled and _player_hover:
		_player_hover.play()


func play_click() -> void:
	if sound_enabled and _player_click:
		_player_click.play()


func play_alert() -> void:
	if sound_enabled and _player_alert:
		_player_alert.play()


## Generates a pleasant electronic blip (freq sweep 450Hz -> 850Hz over 45ms).
func _create_hover_sound() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.045
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var phase := 0.0
	for i in range(sample_count):
		var frac := float(i) / float(sample_count)
		var freq := lerpf(450.0, 850.0, frac)
		phase += (freq * TAU) / float(mix_rate)
		# Smooth attack and decay envelope
		var env := sin(frac * PI)
		var val := sin(phase) * env * 0.35
		var sample := int(clampf(val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


## Generates an arcade laser 'pew' (freq sweep 1100Hz -> 200Hz over 140ms with snappy envelope).
func _create_pew_sound() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.14
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var phase := 0.0
	for i in range(sample_count):
		var frac := float(i) / float(sample_count)
		# Exponential drop for laser "pew"
		var freq := 1100.0 * exp(-frac * 2.8) + 150.0
		phase += (freq * TAU) / float(mix_rate)
		var env := pow(1.0 - frac, 1.6)
		# Add a touch of harmonic overtone
		var val := (sin(phase) * 0.75 + sin(phase * 2.0) * 0.25) * env * 0.45
		var sample := int(clampf(val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


## Generates a subtle chime/tone for alerts.
func _create_alert_sound() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.18
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var phase1 := 0.0
	var phase2 := 0.0
	for i in range(sample_count):
		var frac := float(i) / float(sample_count)
		phase1 += (660.0 * TAU) / float(mix_rate)
		phase2 += (880.0 * TAU) / float(mix_rate)
		var env := exp(-frac * 4.0)
		var val := (sin(phase1) * 0.5 + sin(phase2) * 0.5) * env * 0.3
		var sample := int(clampf(val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

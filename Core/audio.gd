# =============================================================================
# Audio
#
# Single owner of all sound playback. Registered as an autoload named "Audio".
#
# Sounds must be able to last longer than the object that created it. A projectile
# calls queue_free() on impact, so an AudioStreamPlayer parented to that
# projectile is destroyed mid-sample and the impact is cut off. Voices live
# here in a pool instead, and survive whatever spawned the sound.
#
# Pitch is randomised on every call. Identical repetition is what makes a
# frequently-fired sound exhausting, not frequency itself.
# =============================================================================

extends Node

# Simultaneous sound effects.
const SFX_VOICES := 32

var _sfx_pool: Array[AudioStreamPlayer] = []

# Two music players so one can fade in while the other fades out.
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var voice := _free_voice()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_active = _music_a

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p


# --- Sound effects ----------------------------------------------------------

# pitch spread float value gives a variance of +- x percent.
func play_sfx(stream: AudioStream, volume_db := 0.0, pitch_spread := 0.06, base_pitch:= 1.0) -> void:
	if stream == null:
		return

	var voice := _free_voice()
	if voice == null:
		push_warning("SFX pool exhausted, dropping sound")
		return
	if voice == null:
		return   # all voices busy: drop this one rather than cutting another off

	voice.bus = "SFX"
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = base_pitch + randf_range(-pitch_spread, pitch_spread)
	voice.play()


# Picks one of several recordings of the same event.
func play_sfx_varied(streams: Array[AudioStream], volume_db := 0.0, pitch_spread := 0.06, base_pitch := 1.0) -> void:
	if streams.is_empty():
		return
	play_sfx(streams.pick_random(), volume_db, pitch_spread, base_pitch)


# UI sounds bypass the SFX bus so a gameplay volume slider does not silence
# the menus the player is using to adjust it.
func play_ui(stream: AudioStream, volume_db := 0.0) -> void:
	if stream == null:
		return
	var voice := _free_voice()
	if voice == null:
		return
	voice.bus = "UI"
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0
	voice.play()


func _free_voice() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null


# --- Music ------------------------------------------------------------------
func play_music(stream: AudioStream, volume_db := 0.0, fade_time := 1.5) -> void:
	if stream == null:
		return
	if _music_active.stream == stream and _music_active.playing:
		return

	var incoming := _music_b if _music_active == _music_a else _music_a
	var outgoing := _music_active

	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(incoming, "volume_db", volume_db, fade_time)
	t.tween_property(outgoing, "volume_db", -60.0, fade_time)
	t.set_parallel(false)
	t.tween_callback(outgoing.stop)

	_music_active = incoming


func stop_music(fade_time := 1.0) -> void:
	var outgoing := _music_active
	var t := create_tween()
	t.tween_property(outgoing, "volume_db", -60.0, fade_time)
	t.tween_callback(outgoing.stop)


# --- Volume control, for the options menu later -----------------------------
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))

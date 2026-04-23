extends Node

const BACKGROUND_MUSIC_PATH := "res://assets/Sounds/Background Music.mp3"

@export_range(-40.0, 6.0, 0.5) var music_volume_db := -14.0

var _background_music: AudioStream
var _music_player: AudioStreamPlayer
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusicPlayer"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.volume_db = music_volume_db
	add_child(_music_player)

	_background_music = load(BACKGROUND_MUSIC_PATH)


func ensure_playing() -> void:
	if _music_player == null:
		return

	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
		_fade_tween = null

	if _background_music == null:
		_background_music = load(BACKGROUND_MUSIC_PATH)

	if _music_player.stream != _background_music:
		_music_player.stream = _background_music

	_set_stream_looping(_music_player.stream)
	_music_player.volume_db = music_volume_db

	if not _music_player.playing:
		_music_player.play()


func fade_out_and_stop(duration: float = 0.8) -> void:
	if _music_player == null or not _music_player.playing:
		return

	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_music_player, "volume_db", -40.0, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_callback(_stop_music)


func stop_immediately() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
		_fade_tween = null

	_stop_music()


func _exit_tree() -> void:
	if _music_player == null:
		return

	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
		_fade_tween = null

	_stop_music()
	_background_music = null
	_music_player = null


func _stop_music() -> void:
	if _music_player == null:
		return

	_music_player.stop()
	_music_player.stream = null
	_music_player.volume_db = music_volume_db
	_fade_tween = null


func _set_stream_looping(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

extends Area2D

const KEY_INSERT_STREAM := preload("res://assets/Sounds/DoorOpen.mp3")
const GATE_OPEN_STREAM := preload("res://assets/Sounds/gateOpen.mp3")
const KEY_INSERT_SOUND_DURATION := 1.104
const GATE_OPEN_SOUND_DURATION := 4.0 / 3.0
const GATE_OPEN_FADE_DURATION := 0.2

@export var required_key: String = "gold_key"
@export var key_insert_offset: Vector2 = Vector2.ZERO
@export_file("*.tscn") var next_level_scene_path := "res://scenes/LevelOne.tscn"
@export_range(-40.0, 6.0, 0.5) var key_insert_volume_db := -4.0
@export_range(-40.0, 6.0, 0.5) var gate_open_volume_db := -5.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var enter_prompt: Label = $EnterPrompt

var is_open := false
var is_unlocking := false
var player_in_range: CharacterBody2D = null
var is_entering := false
var _key_insert_player: AudioStreamPlayer
var _gate_open_player: AudioStreamPlayer
var _gate_open_delay_tween: Tween
var _gate_open_fade_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	enter_prompt.visible = false
	_setup_audio()

func _physics_process(_delta: float) -> void:
	_update_prompt_visibility()

	if not enter_prompt.visible or is_entering:
		return

	if Input.is_action_just_pressed("interact"):
		is_entering = true
		var scene_transition := get_node_or_null("/root/SceneTransition")
		if scene_transition != null and scene_transition.has_method("change_scene_with_transition"):
			scene_transition.call("change_scene_with_transition", next_level_scene_path)
		else:
			get_tree().change_scene_to_file(next_level_scene_path)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = body as CharacterBody2D

	if is_open or is_unlocking:
		_update_prompt_visibility()
		return

	if not body.has_method("has_key") or not body.has_method("consume_key"):
		return

	if not body.has_key(required_key):
		return

	is_unlocking = true

	var key_node: Node = body.consume_key(required_key)
	if key_node != null and key_node.has_method("use_on_door"):
		key_node.use_on_door(global_position + key_insert_offset)
		await get_tree().create_timer(0.2).timeout

	_play_key_insert_sound()
	open_door()

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		_update_prompt_visibility()

func open_door() -> void:
	is_open = true
	is_unlocking = false
	sprite.play("Open")
	_schedule_gate_open_sound()
	_update_prompt_visibility()

func _update_prompt_visibility() -> void:
	enter_prompt.visible = is_open and is_instance_valid(player_in_range) and not is_entering


func _setup_audio() -> void:
	_key_insert_player = AudioStreamPlayer.new()
	_key_insert_player.name = "KeyInsertPlayer"
	_key_insert_player.stream = KEY_INSERT_STREAM
	_key_insert_player.volume_db = key_insert_volume_db
	add_child(_key_insert_player)

	_gate_open_player = AudioStreamPlayer.new()
	_gate_open_player.name = "GateOpenPlayer"
	_gate_open_player.stream = GATE_OPEN_STREAM
	_gate_open_player.volume_db = gate_open_volume_db
	add_child(_gate_open_player)


func _play_key_insert_sound() -> void:
	if _key_insert_player == null:
		return

	_key_insert_player.play()


func _play_gate_open_sound() -> void:
	if _gate_open_player == null:
		return

	if _gate_open_fade_tween != null and _gate_open_fade_tween.is_running():
		_gate_open_fade_tween.kill()

	_gate_open_player.stop()
	_gate_open_player.volume_db = gate_open_volume_db
	_gate_open_player.play()

	_gate_open_fade_tween = create_tween()
	_gate_open_fade_tween.tween_interval(maxf(GATE_OPEN_SOUND_DURATION - GATE_OPEN_FADE_DURATION, 0.0))
	_gate_open_fade_tween.tween_property(_gate_open_player, "volume_db", -40.0, GATE_OPEN_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gate_open_fade_tween.tween_callback(_stop_gate_open_sound)


func _schedule_gate_open_sound() -> void:
	if _gate_open_delay_tween != null and _gate_open_delay_tween.is_running():
		_gate_open_delay_tween.kill()

	_gate_open_delay_tween = create_tween()
	_gate_open_delay_tween.tween_interval(KEY_INSERT_SOUND_DURATION)
	_gate_open_delay_tween.tween_callback(_play_gate_open_sound)


func _stop_gate_open_sound() -> void:
	if _gate_open_player == null:
		return

	_gate_open_player.stop()
	_gate_open_player.volume_db = gate_open_volume_db
	_gate_open_delay_tween = null
	_gate_open_fade_tween = null

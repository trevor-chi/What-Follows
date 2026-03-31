extends Area2D

@export var required_key: String = "gold_key"
@export var key_insert_offset: Vector2 = Vector2.ZERO
@export_file("*.tscn") var next_level_scene_path := "res://scenes/NextLevel.tscn"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var enter_prompt: Label = $EnterPrompt

var is_open := false
var is_unlocking := false
var player_in_range: CharacterBody2D = null
var is_entering := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	enter_prompt.visible = false

func _physics_process(_delta: float) -> void:
	_update_prompt_visibility()

	if not enter_prompt.visible or is_entering:
		return

	if Input.is_action_just_pressed("interact"):
		is_entering = true
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

	open_door()

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		_update_prompt_visibility()

func open_door() -> void:
	is_open = true
	is_unlocking = false
	sprite.play("Open")
	_update_prompt_visibility()

func _update_prompt_visibility() -> void:
	enter_prompt.visible = is_open and is_instance_valid(player_in_range) and not is_entering

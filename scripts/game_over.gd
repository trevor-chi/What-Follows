extends Control

@export_file("*.tscn") var restart_scene_path := "res://scenes/Main.tscn"

@onready var retry_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RetryButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_retry_button_pressed() -> void:
	get_tree().paused = false

	var retry_scene_path := restart_scene_path
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("get_retry_scene_path"):
		var saved_retry_scene_path = scene_transition.call("get_retry_scene_path") as String
		if not saved_retry_scene_path.is_empty():
			retry_scene_path = saved_retry_scene_path
		if scene_transition.has_method("clear_retry_scene_path"):
			scene_transition.call("clear_retry_scene_path")

	get_tree().change_scene_to_file(retry_scene_path)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

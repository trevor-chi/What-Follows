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
	get_tree().change_scene_to_file(restart_scene_path)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

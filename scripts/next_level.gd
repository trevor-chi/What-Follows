extends Control

const ENDING_BEATS := [
	{
		"title": "The Quiet",
		"body": "The last barrier is behind you, and the long journey finally grows quiet."
	},
	{
		"title": "Still Standing",
		"body": "Every jump, every swap, and every fight brought both halves of the journey to the same ending."
	},
	{
		"title": "What Follows",
		"body": "You made it through the dark and reached the other side. For now, the world is still. The journey is complete."
	}
]
const BODY_FADE_DURATION := 0.45

@export_file("*.tscn") var restart_scene_path := "res://scenes/LevelOne.tscn"
@export_file("*.tscn") var title_scene_path := "res://scenes/TitleScreen.tscn"

@onready var content_margin: MarginContainer = $ContentMargin
@onready var content_column: VBoxContainer = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn
@onready var title_label: Label = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/Title
@onready var body_label: Label = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/Body
@onready var prompt_label: Label = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/Prompt
@onready var button_row: HBoxContainer = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/ButtonRow
@onready var replay_button: Button = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/ButtonRow/ReplayButton
@onready var title_button: Button = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/ButtonRow/TitleButton
@onready var quit_button: Button = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/ButtonRow/QuitButton
@onready var footer_label: Label = $ContentMargin/CenterContainer/PanelContainer/PanelMargin/ContentColumn/Footer
@onready var far_background: Sprite2D = $FarBackground
@onready var mid_background: Sprite2D = $MidBackground
@onready var near_background: Sprite2D = $NearBackground
@onready var top_veil: ColorRect = $TopVeil
@onready var bottom_glow: ColorRect = $BottomGlow

var _beat_index := -1
var _sequence_finished := false
var _transitioning := false
var _beat_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	if not replay_button.pressed.is_connected(_on_replay_button_pressed):
		replay_button.pressed.connect(_on_replay_button_pressed)
	if not title_button.pressed.is_connected(_on_title_button_pressed):
		title_button.pressed.connect(_on_title_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)

	if OS.has_feature("web"):
		quit_button.visible = false

	button_row.visible = false
	button_row.modulate.a = 0.0
	body_label.modulate.a = 0.0
	footer_label.visible = false

	_apply_responsive_layout()
	_show_next_beat()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_advance_or_activate_default()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _sequence_finished:
			_on_title_button_pressed()
			get_viewport().set_input_as_handled()


func _advance_or_activate_default() -> void:
	if _transitioning:
		return

	if _sequence_finished:
		_on_replay_button_pressed()
		return

	_show_next_beat()


func _show_next_beat() -> void:
	if _transitioning:
		return

	_beat_index += 1

	if _beat_index >= ENDING_BEATS.size():
		_finish_sequence()
		return

	var beat: Dictionary = ENDING_BEATS[_beat_index]
	title_label.text = beat["title"]
	body_label.text = beat["body"]

	if _beat_tween != null and _beat_tween.is_running():
		_beat_tween.kill()

	body_label.modulate.a = 0.0
	_beat_tween = create_tween()
	_beat_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_beat_tween.tween_property(body_label, "modulate:a", 1.0, BODY_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if _beat_index == ENDING_BEATS.size() - 1:
		prompt_label.text = "Press Space one more time to continue"
	else:
		prompt_label.text = "Press Space to continue"


func _finish_sequence() -> void:
	_sequence_finished = true
	prompt_label.text = "Choose what follows"
	button_row.visible = true
	footer_label.visible = true

	if _beat_tween != null and _beat_tween.is_running():
		_beat_tween.kill()

	button_row.modulate.a = 0.0
	_beat_tween = create_tween()
	_beat_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_beat_tween.tween_property(button_row, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_replay_button_pressed() -> void:
	_change_scene(restart_scene_path, "Beginning Again", "Stepping back through the first door...")


func _on_title_button_pressed() -> void:
	_change_scene(title_scene_path, "Returning", "Back to the title screen...")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _change_scene(scene_path: String, title: String, subtitle: String) -> void:
	if _transitioning or scene_path.is_empty():
		return

	_transitioning = true
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_with_transition"):
		await scene_transition.change_scene_with_transition(scene_path, title, subtitle)
		if is_inside_tree():
			_transitioning = false
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not load scene: %s" % scene_path)
		_transitioning = false


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var is_compact := viewport_size.x < 1080.0 or viewport_size.y < 760.0
	var side_margin := 22 if is_compact else 36
	var vertical_margin := 22 if is_compact else 30

	content_margin.add_theme_constant_override("margin_left", side_margin)
	content_margin.add_theme_constant_override("margin_top", vertical_margin)
	content_margin.add_theme_constant_override("margin_right", side_margin)
	content_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	content_column.custom_minimum_size = Vector2(clampf(viewport_size.x * (0.9 if is_compact else 0.72), 320.0, 780.0), 0.0)
	content_column.add_theme_constant_override("separation", 14 if is_compact else 18)

	title_label.add_theme_font_size_override("font_size", 62 if is_compact else 92)
	body_label.add_theme_font_size_override("font_size", 34 if is_compact else 46)
	prompt_label.add_theme_font_size_override("font_size", 22 if is_compact else 28)
	replay_button.add_theme_font_size_override("font_size", 24 if is_compact else 28)
	title_button.add_theme_font_size_override("font_size", 24 if is_compact else 28)
	quit_button.add_theme_font_size_override("font_size", 24 if is_compact else 28)
	replay_button.custom_minimum_size = Vector2(180.0 if is_compact else 210.0, 60.0 if is_compact else 68.0)
	title_button.custom_minimum_size = Vector2(180.0 if is_compact else 210.0, 60.0 if is_compact else 68.0)
	quit_button.custom_minimum_size = Vector2(150.0 if is_compact else 180.0, 60.0 if is_compact else 68.0)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER

	_cover_sprite(far_background, viewport_size, 1.0, Vector2.ZERO)
	_cover_sprite(mid_background, viewport_size, 1.08, Vector2.ZERO)
	_cover_sprite(near_background, viewport_size, 1.16, Vector2.ZERO)


func _cover_sprite(sprite: Sprite2D, viewport_size: Vector2, scale_multiplier: float, offset: Vector2) -> void:
	if sprite.texture == null:
		return

	var texture_size := sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var scale_factor := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y) * scale_multiplier
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(
		(viewport_size.x - texture_size.x * scale_factor) * 0.5,
		(viewport_size.y - texture_size.y * scale_factor) * 0.5
	) + offset

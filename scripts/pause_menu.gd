extends CanvasLayer

const TITLE_SCENE_PATH := "res://scenes/TitleScreen.tscn"
const TITLE_HOVER_BG := Color(0.858824, 0.654902, 0.301961, 1.0)
const TITLE_HOVER_BORDER := Color(1.0, 0.956863, 0.823529, 1.0)
const TITLE_PRESSED_BG := Color(0.509804, 0.376471, 0.14902, 1.0)
const TITLE_PRESSED_BORDER := Color(0.996078, 0.901961, 0.690196, 1.0)

var _overlay_root: Control
var _pause_panel: PanelContainer
var _confirm_panel: PanelContainer
var _resume_button: Button
var _quit_button: Button
var _cancel_quit_button: Button
var _confirm_quit_button: Button
var _is_open := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_all()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if not event.is_action_pressed("pause"):
		return

	if _is_transition_busy() or not _can_pause_current_scene():
		return

	if _is_open:
		if _confirm_panel.visible:
			_hide_confirmation()
		else:
			_resume_game()
	else:
		_open_pause_menu()

	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_overlay_root = Control.new()
	_overlay_root.name = "PauseOverlay"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(center)

	var shell := VBoxContainer.new()
	shell.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_theme_constant_override("separation", 22)
	center.add_child(shell)

	_pause_panel = _create_panel(Vector2(520.0, 0.0))
	shell.add_child(_pause_panel)

	var pause_margin := _create_margin_container()
	_pause_panel.add_child(pause_margin)

	var pause_stack := VBoxContainer.new()
	pause_stack.add_theme_constant_override("separation", 18)
	pause_margin.add_child(pause_stack)

	var title := _create_label("Paused", 66, Color(0.96, 0.98, 1.0, 1.0), 10)
	pause_stack.add_child(title)

	var subtitle := _create_label("Take a breath, then choose what you want to do.", 26, Color(0.82, 0.89, 0.98, 0.94))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_stack.add_child(subtitle)

	_resume_button = _create_button("Resume")
	pause_stack.add_child(_resume_button)

	_quit_button = _create_button("Quit To Main Menu")
	pause_stack.add_child(_quit_button)

	_confirm_panel = _create_panel(Vector2(620.0, 0.0))
	shell.add_child(_confirm_panel)

	var confirm_margin := _create_margin_container()
	_confirm_panel.add_child(confirm_margin)

	var confirm_stack := VBoxContainer.new()
	confirm_stack.add_theme_constant_override("separation", 18)
	confirm_margin.add_child(confirm_stack)

	var confirm_title := _create_label("Are You Sure?", 52, Color(0.98, 0.97, 0.93, 1.0), 10)
	confirm_stack.add_child(confirm_title)

	var confirm_body := _create_label(
		"If you quit now, your progress won't be saved.\nYou'll be sent back to the main screen.",
		24,
		Color(0.91, 0.90, 0.86, 0.95)
	)
	confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_stack.add_child(confirm_body)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 18)
	confirm_stack.add_child(button_row)

	_cancel_quit_button = _create_button("Cancel", Vector2(220.0, 72.0))
	button_row.add_child(_cancel_quit_button)

	_confirm_quit_button = _create_button("Quit Anyway", Vector2(220.0, 72.0), true)
	button_row.add_child(_confirm_quit_button)

	if not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)
	if not _cancel_quit_button.pressed.is_connected(_on_cancel_quit_pressed):
		_cancel_quit_button.pressed.connect(_on_cancel_quit_pressed)
	if not _confirm_quit_button.pressed.is_connected(_on_confirm_quit_pressed):
		_confirm_quit_button.pressed.connect(_on_confirm_quit_pressed)


func _create_panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.071, 0.118, 0.97)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.81, 0.90, 1.0, 0.96)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_margin_container() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	return margin


func _create_label(text_value: String, font_size: int, font_color: Color, outline_size: int = 0) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		label.add_theme_constant_override("outline_size", outline_size)
	return label


func _create_button(text_value: String, min_size: Vector2 = Vector2(360.0, 84.0), accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 34)
	var normal_style := _create_button_style(
		Color(0.12, 0.15, 0.22, 0.96)
	)
	var hover_style := _create_button_style(
		TITLE_HOVER_BG,
		TITLE_HOVER_BORDER,
		3,
		8
	)
	var pressed_style := _create_button_style(
		TITLE_PRESSED_BG,
		TITLE_PRESSED_BORDER,
		3
	)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover_pressed", pressed_style)
	return button


func _create_button_style(
	color: Color,
	border_color: Color = Color(0.93, 0.96, 1.0, 1.0),
	border_width: int = 3,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style.shadow_size = shadow_size
	return style


func _open_pause_menu() -> void:
	_is_open = true
	get_tree().paused = true
	_overlay_root.visible = true
	_pause_panel.visible = true
	_confirm_panel.visible = false


func _resume_game() -> void:
	get_tree().paused = false
	_hide_all()


func _show_confirmation() -> void:
	_pause_panel.visible = false
	_confirm_panel.visible = true


func _hide_confirmation() -> void:
	_pause_panel.visible = true
	_confirm_panel.visible = false


func _hide_all() -> void:
	_is_open = false
	if _overlay_root != null:
		_overlay_root.visible = false
	if _pause_panel != null:
		_pause_panel.visible = false
	if _confirm_panel != null:
		_confirm_panel.visible = false


func _can_pause_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false

	if current_scene.scene_file_path == TITLE_SCENE_PATH or current_scene.scene_file_path == "res://scenes/GameOver.tscn":
		return false

	return get_tree().get_first_node_in_group("player") != null


func _is_transition_busy() -> bool:
	var scene_transition := get_node_or_null("/root/SceneTransition")
	return scene_transition != null and scene_transition.has_method("is_transitioning") and scene_transition.call("is_transitioning")


func _on_resume_pressed() -> void:
	_resume_game()


func _on_quit_pressed() -> void:
	_show_confirmation()


func _on_cancel_quit_pressed() -> void:
	_hide_confirmation()


func _on_confirm_quit_pressed() -> void:
	get_tree().paused = false
	_hide_all()

	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_with_transition"):
		scene_transition.call(
			"change_scene_with_transition",
			TITLE_SCENE_PATH,
			"Leaving This Run",
			"Returning to the main screen..."
		)
	else:
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)

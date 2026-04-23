extends CanvasLayer

const FADE_IN_DURATION := 0.7
const HOLD_DURATION := 1.6
const FADE_OUT_DURATION := 0.75

var _overlay_root: Control
var _card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _is_transitioning := false
var _retry_scene_path := ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_set_overlay_alpha(0.0)
	_overlay_root.visible = false


func change_scene_with_transition(
	scene_path: String,
	title: String = "Level Complete",
	subtitle: String = "Crossing into the next level..."
) -> void:
	if scene_path.is_empty() or _is_transitioning:
		return

	_is_transitioning = true
	get_tree().paused = false
	_title_label.text = title
	_subtitle_label.text = subtitle
	_overlay_root.visible = true
	_set_overlay_alpha(0.0)
	_prepare_card_for_transition()

	await _animate_overlay_alpha(1.0, FADE_IN_DURATION)
	await get_tree().create_timer(HOLD_DURATION).timeout

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not load scene: %s" % scene_path)
		await _animate_overlay_alpha(0.0, FADE_OUT_DURATION)
		_overlay_root.visible = false
		_is_transitioning = false
		return

	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	await _animate_overlay_alpha(0.0, FADE_OUT_DURATION)

	_overlay_root.visible = false
	_is_transitioning = false


func is_transitioning() -> bool:
	return _is_transitioning


func set_retry_scene_path(scene_path: String) -> void:
	_retry_scene_path = scene_path


func get_retry_scene_path() -> String:
	return _retry_scene_path


func clear_retry_scene_path() -> void:
	_retry_scene_path = ""


func _build_overlay() -> void:
	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.color = Color(0.020, 0.027, 0.043, 0.96)
	_overlay_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(520.0, 260.0)
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_card)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.045, 0.065, 0.114, 0.97)
	card_style.border_width_left = 4
	card_style.border_width_top = 4
	card_style.border_width_right = 4
	card_style.border_width_bottom = 4
	card_style.border_color = Color(0.749, 0.882, 1.0, 0.95)
	card_style.corner_radius_top_left = 24
	card_style.corner_radius_top_right = 24
	card_style.corner_radius_bottom_right = 24
	card_style.corner_radius_bottom_left = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	card_style.shadow_size = 28
	_card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 38)
	_card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.text = "Level Complete"
	stack.add_child(_title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(220.0, 5.0)
	divider.color = Color(0.341, 0.784, 0.914, 0.85)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(divider)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 28)
	_subtitle_label.add_theme_color_override("font_color", Color(0.83, 0.90, 0.98, 0.95))
	_subtitle_label.text = "Crossing into the next level..."
	stack.add_child(_subtitle_label)


func _set_overlay_alpha(alpha: float) -> void:
	if _overlay_root == null:
		return

	var overlay_modulate := _overlay_root.modulate
	overlay_modulate.a = alpha
	_overlay_root.modulate = overlay_modulate


func _animate_overlay_alpha(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay_root, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _prepare_card_for_transition() -> void:
	if _card == null:
		return

	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	_card.modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_card, "scale", Vector2.ONE, FADE_IN_DURATION + 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, FADE_IN_DURATION * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

extends Control

enum TitleTab {
	OVERVIEW,
	CONTROLS,
}

enum StagePhase {
	IDLE,
	RUN,
	ATTACK,
}

const TITLE_IDLE_ANIMATION := &"Idle"
const TITLE_RUN_ANIMATION := &"Running"
const TITLE_ATTACK_ANIMATIONS := [&"Attack_1", &"Attack_2", &"Attack_3"]
const TITLE_IDLE_DURATION := 1.1
const TITLE_LOOP_IDLE_DURATION := 1.45
const TITLE_RUN_DURATION := 2.4
const TITLE_SHADOW_DELAY_TICKS := 72.0

@export_file("*.tscn") var game_scene_path := "res://scenes/Main.tscn"
@export_range(0.0, 1.0, 0.05) var title_swap_chance := 0.5

@onready var content_margin: MarginContainer = $UI/ContentMargin
@onready var content_column: VBoxContainer = $UI/ContentMargin/CenterContainer/ContentColumn
@onready var tab_content: MarginContainer = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent
@onready var controls_tab_button: Button = $UI/ContentMargin/CenterContainer/ContentColumn/ActionCenter/ActionStack/ControlsTabButton
@onready var overview_panel: VBoxContainer = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/OverviewPanel
@onready var controls_panel: VBoxContainer = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel
@onready var controls_list: VBoxContainer = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/ControlsList
@onready var action_center: CenterContainer = $UI/ContentMargin/CenterContainer/ContentColumn/ActionCenter
@onready var action_stack: VBoxContainer = $UI/ContentMargin/CenterContainer/ContentColumn/ActionCenter/ActionStack
@onready var start_button: Button = $UI/ContentMargin/CenterContainer/ContentColumn/ActionCenter/ActionStack/StartButton
@onready var quit_button: Button = $UI/ContentMargin/CenterContainer/ContentColumn/ActionCenter/ActionStack/QuitButton
@onready var controls_back_button: Button = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/BackCenter/BackToMainButton
@onready var title_label: Label = $UI/ContentMargin/CenterContainer/ContentColumn/Title
@onready var subtitle_label: Label = $UI/ContentMargin/CenterContainer/ContentColumn/Subtitle
@onready var move_line: Label = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/ControlsList/MoveLine
@onready var jump_line: Label = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/ControlsList/JumpLine
@onready var swap_line: Label = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/ControlsList/SwapLine
@onready var interact_line: Label = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/ControlsList/InteractLine
@onready var attack_line: Label = $UI/ContentMargin/CenterContainer/ContentColumn/TabContent/ControlsPanel/ControlsList/AttackLine
@onready var floor: ColorRect = $Floor
@onready var floor_edge: ColorRect = $FloorEdge
@onready var far_background: Sprite2D = $FarBackground
@onready var mid_background: Sprite2D = $MidBackground
@onready var near_background: Sprite2D = $NearBackground
@onready var shadow_glow: AnimatedSprite2D = $Stage/ShadowGlow
@onready var shadow_outline: AnimatedSprite2D = $Stage/ShadowOutline
@onready var shadow_sprite: AnimatedSprite2D = $Stage/ShadowSprite
@onready var hero_sprite: AnimatedSprite2D = $Stage/HeroSprite

var _transitioning := false
var _active_tab := TitleTab.OVERVIEW
var _stage_clock := 0.0
var _phase_deadline := 0.0
var _attack_index := -1
var _shadow_animation_queue: Array[Dictionary] = []
var _stage_phase := StagePhase.IDLE
var _sprites_swapped := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_rng.randomize()

	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)
	if not controls_tab_button.pressed.is_connected(_on_controls_tab_pressed):
		controls_tab_button.pressed.connect(_on_controls_tab_pressed)
	if not controls_back_button.pressed.is_connected(_on_controls_back_button_pressed):
		controls_back_button.pressed.connect(_on_controls_back_button_pressed)
	if not hero_sprite.animation_finished.is_connected(_on_hero_sprite_animation_finished):
		hero_sprite.animation_finished.connect(_on_hero_sprite_animation_finished)

	if OS.has_feature("web"):
		quit_button.visible = false

	_set_active_tab(TitleTab.OVERVIEW)
	_apply_responsive_layout()
	_play_shadow_animation(TITLE_IDLE_ANIMATION)
	_sync_title_shadow_outline()
	_start_idle_phase(TITLE_IDLE_DURATION)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_responsive_layout()


func _process(delta: float) -> void:
	_stage_clock += delta
	_flush_shadow_animation_queue()
	_sync_title_shadow_outline()

	if _stage_phase == StagePhase.IDLE and _stage_clock >= _phase_deadline:
		_start_run_phase()
	elif _stage_phase == StagePhase.RUN and _stage_clock >= _phase_deadline:
		_play_next_attack()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_set_active_tab(TitleTab.CONTROLS if _active_tab == TitleTab.OVERVIEW else TitleTab.OVERVIEW)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _active_tab == TitleTab.CONTROLS:
				_set_active_tab(TitleTab.OVERVIEW)
				get_viewport().set_input_as_handled()
			elif quit_button.visible:
				_quit_game()
				get_viewport().set_input_as_handled()


func _on_start_button_pressed() -> void:
	_start_game()


func _on_quit_button_pressed() -> void:
	_quit_game()


func _on_controls_tab_pressed() -> void:
	_set_active_tab(TitleTab.CONTROLS)


func _on_controls_back_button_pressed() -> void:
	_set_active_tab(TitleTab.OVERVIEW)


func _on_hero_sprite_animation_finished() -> void:
	if _stage_phase == StagePhase.ATTACK and _attack_index >= 0 and hero_sprite.animation == TITLE_ATTACK_ANIMATIONS[_attack_index]:
		_play_next_attack()


func _set_active_tab(tab: TitleTab) -> void:
	_active_tab = tab
	var showing_overview := tab == TitleTab.OVERVIEW

	overview_panel.visible = showing_overview
	controls_panel.visible = not showing_overview
	title_label.visible = showing_overview
	subtitle_label.visible = showing_overview
	action_center.visible = showing_overview


func _start_game() -> void:
	if _transitioning:
		return

	_transitioning = true
	var error := get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		push_error("Could not load game scene: %s" % game_scene_path)
		_transitioning = false


func _quit_game() -> void:
	get_tree().quit()


func _start_idle_phase(duration: float) -> void:
	_stage_phase = StagePhase.IDLE
	_attack_index = -1
	_play_hero_animation(TITLE_IDLE_ANIMATION)
	_schedule_shadow_animation(TITLE_IDLE_ANIMATION)
	_phase_deadline = _stage_clock + duration


func _start_run_phase() -> void:
	_stage_phase = StagePhase.RUN
	_attack_index = -1
	_play_hero_animation(TITLE_RUN_ANIMATION)
	_schedule_shadow_animation(TITLE_RUN_ANIMATION)
	_phase_deadline = _stage_clock + TITLE_RUN_DURATION


func _play_next_attack() -> void:
	if _attack_index < TITLE_ATTACK_ANIMATIONS.size() - 1:
		_stage_phase = StagePhase.ATTACK
		_attack_index += 1
		var attack_animation: StringName = TITLE_ATTACK_ANIMATIONS[_attack_index]
		_play_hero_animation(attack_animation)
		_schedule_shadow_animation(attack_animation)
		return

	_maybe_swap_stage_sides()
	_start_idle_phase(TITLE_LOOP_IDLE_DURATION)


func _play_hero_animation(animation_name: StringName) -> void:
	hero_sprite.play(animation_name)


func _play_shadow_animation(animation_name: StringName) -> void:
	shadow_outline.play(animation_name)
	shadow_sprite.play(animation_name)
	shadow_glow.play(animation_name)
	_sync_title_shadow_outline()


func _schedule_shadow_animation(animation_name: StringName) -> void:
	_shadow_animation_queue.append({
		"time": _stage_clock + _get_shadow_delay_seconds(),
		"animation": animation_name,
	})


func _flush_shadow_animation_queue() -> void:
	while not _shadow_animation_queue.is_empty():
		var queued_animation := _shadow_animation_queue[0]
		if float(queued_animation["time"]) > _stage_clock:
			return

		var animation_name := queued_animation["animation"] as StringName
		_play_shadow_animation(animation_name)
		_shadow_animation_queue.pop_front()


func _get_shadow_delay_seconds() -> float:
	return TITLE_SHADOW_DELAY_TICKS / maxf(float(Engine.physics_ticks_per_second), 1.0)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var is_compact := viewport_size.x < 1180.0 or viewport_size.y < 760.0
	var side_margin := 24 if is_compact else 56
	var top_margin := 24 if is_compact else 42
	var bottom_margin := 20 if is_compact else 36

	content_margin.add_theme_constant_override("margin_left", side_margin)
	content_margin.add_theme_constant_override("margin_top", top_margin)
	content_margin.add_theme_constant_override("margin_right", side_margin)
	content_margin.add_theme_constant_override("margin_bottom", bottom_margin)
	content_column.add_theme_constant_override("separation", 18 if is_compact else 24)
	tab_content.add_theme_constant_override("margin_top", 12 if is_compact else 18)
	tab_content.add_theme_constant_override("margin_bottom", 12 if is_compact else 18)
	content_column.custom_minimum_size = Vector2(
		clampf(viewport_size.x * (0.94 if is_compact else 0.8), 360.0, 1120.0),
		0.0
	)

	var floor_top := viewport_size.y * (0.85 if is_compact else 0.84)
	floor.position = Vector2(0.0, floor_top)
	floor.size = Vector2(viewport_size.x, viewport_size.y - floor_top)
	floor_edge.position = Vector2(0.0, floor_top - 6.0)
	floor_edge.size = Vector2(viewport_size.x, 6.0)

	_cover_sprite(far_background, viewport_size, 1.0, Vector2.ZERO)
	_cover_sprite(mid_background, viewport_size, 1.08, Vector2.ZERO)
	_cover_sprite(near_background, viewport_size, 1.16, Vector2.ZERO)
	_apply_stage_layout(viewport_size, is_compact)

	title_label.add_theme_font_size_override("font_size", 96 if is_compact else 168)
	subtitle_label.add_theme_font_size_override("font_size", 34 if is_compact else 58)
	move_line.add_theme_font_size_override("font_size", 34 if is_compact else 58)
	jump_line.add_theme_font_size_override("font_size", 34 if is_compact else 58)
	swap_line.add_theme_font_size_override("font_size", 34 if is_compact else 58)
	interact_line.add_theme_font_size_override("font_size", 34 if is_compact else 58)
	attack_line.add_theme_font_size_override("font_size", 34 if is_compact else 58)
	start_button.add_theme_font_size_override("font_size", 34 if is_compact else 42)
	quit_button.add_theme_font_size_override("font_size", 34 if is_compact else 42)
	controls_tab_button.add_theme_font_size_override("font_size", 34 if is_compact else 42)
	controls_back_button.add_theme_font_size_override("font_size", 34 if is_compact else 42)
	start_button.custom_minimum_size = Vector2(360.0 if is_compact else 480.0, 88.0 if is_compact else 112.0)
	quit_button.custom_minimum_size = Vector2(360.0 if is_compact else 480.0, 88.0 if is_compact else 112.0)
	controls_tab_button.custom_minimum_size = Vector2(360.0 if is_compact else 480.0, 88.0 if is_compact else 112.0)
	controls_back_button.custom_minimum_size = Vector2(360.0 if is_compact else 480.0, 88.0 if is_compact else 112.0)
	controls_panel.add_theme_constant_override("separation", 24 if is_compact else 30)
	controls_list.add_theme_constant_override("separation", 20 if is_compact else 26)
	action_stack.add_theme_constant_override("separation", 14 if is_compact else 20)


func _apply_stage_layout(viewport_size: Vector2, is_compact: bool) -> void:
	var center_x := viewport_size.x * 0.5
	var stage_y := viewport_size.y * (0.62 if is_compact else 0.6)
	var base_scale := clampf(viewport_size.y / 150.0, 3.4, 5.7)
	var left_offset := viewport_size.x * (0.18 if is_compact else 0.2)
	var right_offset := viewport_size.x * (0.2 if is_compact else 0.22)
	var left_x := center_x - left_offset
	var right_x := center_x + right_offset
	var shadow_x := right_x if _sprites_swapped else left_x
	var hero_x := left_x if _sprites_swapped else right_x

	shadow_sprite.position = Vector2(shadow_x, stage_y)
	shadow_sprite.scale = Vector2(base_scale, base_scale)
	shadow_sprite.flip_h = _sprites_swapped

	shadow_outline.position = shadow_sprite.position
	shadow_outline.scale = shadow_sprite.scale
	shadow_outline.flip_h = shadow_sprite.flip_h
	_sync_title_shadow_outline()

	shadow_glow.position = shadow_sprite.position + Vector2(12.0, 10.0)
	shadow_glow.scale = Vector2(base_scale * 1.02, base_scale * 1.02)
	shadow_glow.flip_h = shadow_sprite.flip_h

	hero_sprite.position = Vector2(hero_x, stage_y)
	hero_sprite.scale = Vector2(base_scale, base_scale)
	hero_sprite.flip_h = not _sprites_swapped


func _sync_title_shadow_outline() -> void:
	if shadow_outline == null or shadow_sprite == null:
		return

	if shadow_outline.animation != shadow_sprite.animation:
		shadow_outline.play(shadow_sprite.animation)
	elif not shadow_outline.is_playing() and shadow_sprite.is_playing():
		shadow_outline.play()

	shadow_outline.position = shadow_sprite.position
	shadow_outline.scale = shadow_sprite.scale
	shadow_outline.flip_h = shadow_sprite.flip_h
	shadow_outline.frame = shadow_sprite.frame
	shadow_outline.frame_progress = shadow_sprite.frame_progress

	if not shadow_sprite.is_playing():
		shadow_outline.pause()


func _maybe_swap_stage_sides() -> void:
	if title_swap_chance <= 0.0 or _rng.randf() > title_swap_chance:
		return

	_sprites_swapped = not _sprites_swapped
	_apply_responsive_layout()


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

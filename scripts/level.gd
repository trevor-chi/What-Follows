# MainScene.gd
extends Node2D

const PLAYER_WALL_LAYER := 8
const SHADOW_WALL_LAYER := 16
const DOOR_PLATFORM_TILES := [
	Vector2i(23, 1),
	Vector2i(24, 1),
	Vector2i(25, 1),
	Vector2i(26, 1),
	Vector2i(27, 1),
]
const KEY_PLATFORM_TILES := [
	Vector2i(27, 5),
	Vector2i(28, 5),
	Vector2i(29, 5),
	Vector2i(30, 5),
	Vector2i(31, 5),
	Vector2i(32, 5),
	Vector2i(33, 5),
]
const LEVEL_ONE_SHADOW_GAP_FIX_START := Vector2i(14, 5)
const LEVEL_ONE_SHADOW_GAP_FIX_END := Vector2i(24, 11)

enum TutorialStep {
	MOVE,
	JUMP,
	SHADOW_ZONE,
	SHADOW_PREP,
	CROSS_SWAP,
	APPROACH_ENEMY,
	RETURN_SWAP,
	COMBAT,
	POST_COMBAT_SWAP,
	KEY,
	DOOR,
	DONE,
}

@export var player: CharacterBody2D
@export var shadow: CharacterBody2D
@export var enemy: CharacterBody2D
@export var key: Node
@export var camera_min_zoom := 0.45
@export var camera_max_zoom := 0.72
@export var camera_padding := Vector2(320.0, 180.0)
@export_range(0.0, 1.0) var camera_shadow_weight := 0.5
@export var camera_position_smoothing := 5.0
@export var camera_zoom_smoothing := 4.0
@export var reveal_key_on_spawn := false
@export var key_reveal_duration := 1.35
@export var level_wall_thickness := 128.0
@export var level_wall_vertical_padding := 256.0
@export var shadow_wall_extra_margin := 0.0
@export var door_platform_drop_rows := 2
@export var key_platform_drop_rows := 0
@export var fall_reset_margin := 256.0
@export var tutorial_prompt_display_time := 3.5

@onready var _tutorial_prompt_panel := get_node_or_null("TutorialUI/TutorialPrompt") as Control
@onready var _tutorial_title_label := get_node_or_null("TutorialUI/TutorialPrompt/PromptMargin/PromptStack/TutorialTitle") as Label
@onready var _tutorial_body_label := get_node_or_null("TutorialUI/TutorialPrompt/PromptMargin/PromptStack/TutorialBody") as Label
@onready var _tutorial_continue_label := get_node_or_null("TutorialUI/TutorialPrompt/PromptMargin/PromptStack/TutorialContinue") as Label
@onready var _tutorial_objective_stack := get_node_or_null("TutorialUI/TutorialPrompt/PromptMargin/PromptStack/ObjectiveStack") as Control
@onready var _tutorial_objective_title_label := get_node_or_null("TutorialUI/TutorialPrompt/PromptMargin/PromptStack/ObjectiveStack/ObjectiveTitle") as Label
@onready var _tutorial_objective_label := get_node_or_null("TutorialUI/TutorialPrompt/PromptMargin/PromptStack/ObjectiveStack/TutorialObjective") as Label
@onready var _tutorial_shadow_area := get_node_or_null("ShadowArea") as Node2D

var _swap_requested := false
var _player_start_position := Vector2.ZERO
var _shadow_start_position := Vector2.ZERO
var _enemy_start_position := Vector2.ZERO
var _key_start_position := Vector2.ZERO
var _fall_reset_y := INF
var _camera_bounds := Rect2()
var _key_reveal_time_remaining := 0.0
var _tutorial_active := false
var _tutorial_prompt_waiting := false
var _tutorial_step := -1
var _tutorial_resume_step := -1
var _tutorial_resume_objective := ""
var _tutorial_jump_seen := false
var _tutorial_swap_count := 0
var _tutorial_move_left_presses := 0
var _tutorial_move_right_presses := 0
var _tutorial_move_step_ready_time_ms := -1
var _tutorial_swap_checkpoint := 0
var _tutorial_prompt_time_remaining := 0.0
var _tutorial_prompt_active := false

func _ready() -> void:
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	if enemy and enemy.has_signal("defeated"):
		if not enemy.defeated.is_connected(_on_enemy_defeated):
			enemy.defeated.connect(_on_enemy_defeated)

	if key and key.has_method("set_available"):
		key.call("set_available", false)

	if player:
		_player_start_position = player.global_position
	if shadow:
		_shadow_start_position = shadow.global_position

	_lower_door_platform_section()
	_lower_key_platform_section()
	_fix_level_one_shadow_gap()

	if enemy:
		_enemy_start_position = enemy.global_position
	if key is Node2D:
		_key_start_position = (key as Node2D).global_position

	_setup_level_walls()
	_configure_level_camera()
	_setup_tutorial()

func _unhandled_input(event):
	if _tutorial_prompt_active:
		return

	_record_tutorial_input(event)

	if event.is_action_pressed("swap_sprites"):
		_swap_requested = true

func _physics_process(delta):
	if _swap_requested:
		_swap_requested = false
		swap_positions()

	if _reset_on_fall():
		return

	if _key_reveal_time_remaining > 0.0:
		_key_reveal_time_remaining = maxf(_key_reveal_time_remaining - delta, 0.0)

	if _tutorial_prompt_time_remaining > 0.0:
		_tutorial_prompt_time_remaining = maxf(_tutorial_prompt_time_remaining - delta, 0.0)
		if _tutorial_prompt_time_remaining <= 0.0:
			_advance_tutorial_prompt()

	_update_tutorial_flow()
	_enforce_tutorial_shadow_zone_block()
	_update_level_camera(delta)

func swap_positions():
	if not player or not shadow:
		return

	var p_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var s_sprite := shadow.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if not p_sprite or not s_sprite:
		return

	var p_sprite_pos := p_sprite.global_position
	var s_sprite_pos := s_sprite.global_position

	var p_vel := player.velocity
	var s_vel := shadow.velocity

	player.global_position += (s_sprite_pos - p_sprite_pos)
	shadow.global_position += (p_sprite_pos - s_sprite_pos)

	player.velocity = s_vel
	shadow.velocity = p_vel

	if shadow.has_method("reset_queue"):
		shadow.reset_queue()

	if _tutorial_active:
		_tutorial_swap_count += 1

func _on_enemy_defeated() -> void:
	if key and key.has_method("set_available"):
		key.call("set_available", true)

	if reveal_key_on_spawn and key is Node2D:
		_key_reveal_time_remaining = key_reveal_duration

func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _is_tutorial_level() -> bool:
	return name == "Tutorial"


func _setup_tutorial() -> void:
	if not _is_tutorial_level():
		return

	_tutorial_active = true
	_restart_tutorial()


func _restart_tutorial() -> void:
	if not _is_tutorial_level():
		return

	_tutorial_active = true
	_tutorial_jump_seen = false
	_tutorial_swap_count = 0
	_tutorial_step = -1
	_tutorial_resume_step = -1
	_tutorial_resume_objective = ""
	_tutorial_move_left_presses = 0
	_tutorial_move_right_presses = 0
	_tutorial_move_step_ready_time_ms = -1
	_tutorial_swap_checkpoint = 0
	_tutorial_prompt_waiting = false
	_tutorial_prompt_time_remaining = 0.0
	_tutorial_prompt_active = false
	_set_tutorial_objective("")
	_make_tutorial_enemy_safe()
	_set_enemy_tutorial_enabled(false)
	_pause_tutorial(
		TutorialStep.MOVE,
		"Learn the Basics",
		"A and D move.\nW jumps.\nSpace swaps places with your shadow.",
		""
	)


func _pause_tutorial(next_step: int, title: String, body: String, objective_after: String) -> void:
	_tutorial_prompt_waiting = false
	_tutorial_resume_step = -1
	_tutorial_resume_objective = ""
	_tutorial_step = next_step
	_tutorial_prompt_time_remaining = tutorial_prompt_display_time
	_tutorial_prompt_active = true
	_swap_requested = false
	_set_tutorial_controls_locked(true)

	if _tutorial_prompt_panel:
		_tutorial_prompt_panel.visible = true
	if _tutorial_title_label:
		_tutorial_title_label.text = title
	if _tutorial_body_label:
		_tutorial_body_label.text = body
	if _tutorial_continue_label:
		_tutorial_continue_label.visible = false
		_tutorial_continue_label.text = ""

	_apply_tutorial_step_state()
	if _tutorial_step == TutorialStep.MOVE:
		_set_tutorial_objective("")
	else:
		_set_tutorial_objective(objective_after)
	_refresh_tutorial_prompt_panel()


func _pause_tutorial_for_swap(next_step: int, title: String, body: String, objective_after: String) -> void:
	_tutorial_swap_checkpoint = _tutorial_swap_count
	_pause_tutorial(next_step, title, body, objective_after)


func _advance_tutorial_prompt() -> void:
	if not _tutorial_prompt_active:
		return

	_tutorial_prompt_waiting = false
	_tutorial_prompt_time_remaining = 0.0
	_tutorial_prompt_active = false
	_apply_tutorial_step_state()
	_set_tutorial_controls_locked(false)
	if _tutorial_step == TutorialStep.MOVE:
		_update_move_tutorial_objective()
	_refresh_tutorial_prompt_panel()


func _apply_tutorial_step_state() -> void:
	if not _is_tutorial_level():
		return

	match _tutorial_step:
		TutorialStep.MOVE, TutorialStep.JUMP, TutorialStep.SHADOW_ZONE, TutorialStep.SHADOW_PREP, TutorialStep.CROSS_SWAP, TutorialStep.APPROACH_ENEMY, TutorialStep.RETURN_SWAP:
			_set_enemy_tutorial_enabled(false)
		TutorialStep.COMBAT, TutorialStep.POST_COMBAT_SWAP, TutorialStep.KEY, TutorialStep.DOOR, TutorialStep.DONE:
			_set_enemy_tutorial_enabled(true)
		_:
			_set_enemy_tutorial_enabled(false)


func _update_tutorial_flow() -> void:
	if not _tutorial_active or _tutorial_prompt_waiting or _tutorial_prompt_active or not player:
		return

	match _tutorial_step:
		TutorialStep.MOVE:
			if _tutorial_move_left_presses >= 2 and _tutorial_move_right_presses >= 2:
				if _tutorial_move_step_ready_time_ms < 0:
					_tutorial_move_step_ready_time_ms = Time.get_ticks_msec() + 3000
					_set_tutorial_objective("Nice. You have movement down.")
				elif Time.get_ticks_msec() >= _tutorial_move_step_ready_time_ms:
					_pause_tutorial(
						TutorialStep.JUMP,
						"Jumping",
						"Press W to jump.\nUse jumps to clear ledges and gaps.",
						"Jump once with W."
					)
		TutorialStep.JUMP:
			if player.get("did_jump_this_frame") == true:
				_tutorial_jump_seen = true
			if _tutorial_jump_seen and player.is_on_floor():
				_pause_tutorial(
					TutorialStep.SHADOW_ZONE,
					"Shadow Zones",
					"Shadow zones consume the player.\nYour shadow can pass through them safely.",
					"Walk toward the shadow zone."
				)
		TutorialStep.SHADOW_ZONE:
			if _tutorial_reached_shadow_zone():
				_pause_tutorial_for_swap(
					TutorialStep.CROSS_SWAP,
					"Swap Across",
					"Your shadow is in position.\nPress Space to switch and cross the zone.",
					"Press Space to cross the shadow zone."
				)
		TutorialStep.CROSS_SWAP:
			if _tutorial_swap_count > _tutorial_swap_checkpoint and _tutorial_player_past_shadow_zone():
				_pause_tutorial(
					TutorialStep.APPROACH_ENEMY,
					"Approach the Enemy",
					"Now walk toward the enemy.\nWhen you reach it, the tutorial will tell you when to switch back.",
					"Walk toward the enemy."
				)
		TutorialStep.APPROACH_ENEMY:
			if _tutorial_ready_for_enemy_swap_back():
				_pause_tutorial_for_swap(
					TutorialStep.RETURN_SWAP,
					"Switch Back",
					"You are in position.\nPress Space to switch back before the fight.",
					"Press Space to switch back."
				)
		TutorialStep.RETURN_SWAP:
			if _tutorial_swap_count > _tutorial_swap_checkpoint:
				_pause_tutorial(
					TutorialStep.COMBAT,
					"Combat",
					"Only the player can attack.\nThe shadow cannot hurt enemies.\nUse left click to defeat the enemy.",
					"Defeat the enemy with left click."
				)
		TutorialStep.COMBAT:
			if enemy == null or enemy.get("is_dead") == true:
				_pause_tutorial_for_swap(
					TutorialStep.POST_COMBAT_SWAP,
					"Switch Again",
					"The enemy is down.\nPress Space to switch back and keep moving.",
					"Press Space to switch back."
				)
		TutorialStep.POST_COMBAT_SWAP:
			if _tutorial_swap_count > _tutorial_swap_checkpoint:
				_pause_tutorial(
					TutorialStep.KEY,
					"The Key",
					"Defeating the enemy revealed the key.\nPick it up and carry it to the exit.",
					"Pick up the key."
				)
		TutorialStep.KEY:
			if _player_has_tutorial_key():
				_pause_tutorial(
					TutorialStep.DOOR,
					"The Door",
					"Bring the key to the door to unlock it.\nThen press E to enter.",
					"Go to the door and press E."
				)
		TutorialStep.DOOR:
			if _door_is_open():
				_tutorial_step = TutorialStep.DONE
				_tutorial_active = false
				_set_tutorial_objective("")
		_:
			pass


func _set_tutorial_controls_locked(locked: bool) -> void:
	if player and player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", not locked)

	if shadow and shadow.has_method("set_follow_enabled"):
		shadow.call("set_follow_enabled", not locked)

	if enemy and enemy.has_method("set_ai_enabled"):
		enemy.call("set_ai_enabled", not locked and _tutorial_step >= TutorialStep.COMBAT)


func _set_enemy_tutorial_enabled(enabled: bool) -> void:
	if enemy and enemy.has_method("set_ai_enabled"):
		enemy.call("set_ai_enabled", enabled and not _tutorial_prompt_waiting and not _tutorial_prompt_active)
	if enemy and enemy.has_method("set_damage_enabled"):
		enemy.call("set_damage_enabled", enabled and not _tutorial_prompt_active)


func _set_tutorial_objective(text: String) -> void:
	if not _tutorial_objective_label or not _tutorial_objective_title_label:
		return

	var has_text := not text.is_empty()
	_tutorial_objective_label.text = text if has_text else ""
	_refresh_tutorial_prompt_panel()


func _player_has_tutorial_key() -> bool:
	return player != null and player.has_method("has_key") and player.call("has_key", "gold_key")


func _record_tutorial_input(event: InputEvent) -> void:
	if not _tutorial_active or _tutorial_prompt_waiting or _tutorial_prompt_active or _tutorial_step != TutorialStep.MOVE:
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if event.is_action_pressed("move_left"):
		_tutorial_move_left_presses += 1
		_update_move_tutorial_objective()
	elif event.is_action_pressed("move_right"):
		_tutorial_move_right_presses += 1
		_update_move_tutorial_objective()


func _update_move_tutorial_objective() -> void:
	if _tutorial_move_left_presses >= 2 and _tutorial_move_right_presses >= 2:
		_set_tutorial_objective("Nice. You have movement down.")
		return

	_set_tutorial_objective(
		"Tap A twice and D twice.  A: %d/2  D: %d/2" % [
			mini(_tutorial_move_left_presses, 2),
			mini(_tutorial_move_right_presses, 2),
		]
	)


func _refresh_tutorial_prompt_panel() -> void:
	if _tutorial_prompt_panel == null:
		return

	var has_objective := _tutorial_objective_label != null and not _tutorial_objective_label.text.is_empty()
	var show_objective := has_objective and not _tutorial_prompt_active
	_tutorial_prompt_panel.visible = _tutorial_prompt_active or show_objective

	if _tutorial_title_label:
		_tutorial_title_label.visible = _tutorial_prompt_active
	if _tutorial_body_label:
		_tutorial_body_label.visible = _tutorial_prompt_active
	if _tutorial_continue_label:
		_tutorial_continue_label.visible = false
	if _tutorial_objective_stack:
		_tutorial_objective_stack.visible = show_objective
	if _tutorial_objective_title_label:
		_tutorial_objective_title_label.visible = show_objective
	if _tutorial_objective_label:
		_tutorial_objective_label.visible = show_objective


func _enforce_tutorial_shadow_zone_block() -> void:
	if not _tutorial_should_block_shadow_zone_entry():
		return
	if player == null:
		return

	var left_edge := _get_tutorial_shadow_zone_left_edge()
	if left_edge == INF:
		return

	var max_player_x := left_edge - 20.0
	if player.global_position.x <= max_player_x:
		return

	player.global_position.x = max_player_x
	player.velocity.x = minf(player.velocity.x, 0.0)


func _tutorial_should_block_shadow_zone_entry() -> bool:
	if not _tutorial_active:
		return false
	if _tutorial_step != TutorialStep.SHADOW_ZONE and _tutorial_step != TutorialStep.CROSS_SWAP:
		return false
	return not _tutorial_player_past_shadow_zone()


func _tutorial_reached_shadow_zone() -> bool:
	if player == null:
		return false
	if _tutorial_shadow_area == null:
		return player.global_position.x >= _player_start_position.x + 160.0

	var left_edge := _get_tutorial_shadow_zone_left_edge()
	if left_edge == INF:
		return player.global_position.x >= _tutorial_shadow_area.global_position.x - 220.0
	return player.global_position.x >= left_edge - 220.0


func _tutorial_shadow_past_shadow_zone() -> bool:
	if shadow == null:
		return false

	var right_edge := _get_tutorial_shadow_zone_right_edge()
	if right_edge == INF:
		return shadow.global_position.x >= _player_start_position.x + 320.0
	return shadow.global_position.x >= right_edge + 36.0


func _tutorial_player_past_shadow_zone() -> bool:
	if player == null:
		return false

	var right_edge := _get_tutorial_shadow_zone_right_edge()
	if right_edge == INF:
		return player.global_position.x >= _player_start_position.x + 320.0
	return player.global_position.x >= right_edge + 36.0


func _tutorial_ready_for_enemy_swap_back() -> bool:
	if player == null:
		return false
	return _tutorial_player_past_shadow_zone() and _tutorial_shadow_past_shadow_zone()


func _get_tutorial_shadow_zone_left_edge() -> float:
	if _tutorial_shadow_area == null:
		return INF

	var collision_shape := _tutorial_shadow_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision_shape.shape as RectangleShape2D if collision_shape else null
	if rectangle == null:
		return INF

	var half_width := rectangle.size.x * 0.5 * absf(collision_shape.global_scale.x)
	return collision_shape.global_position.x - half_width


func _get_tutorial_shadow_zone_right_edge() -> float:
	if _tutorial_shadow_area == null:
		return INF

	var collision_shape := _tutorial_shadow_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision_shape.shape as RectangleShape2D if collision_shape else null
	if rectangle == null:
		return INF

	var half_width := rectangle.size.x * 0.5 * absf(collision_shape.global_scale.x)
	return collision_shape.global_position.x + half_width


func _make_tutorial_enemy_safe() -> void:
	if enemy == null:
		return
	enemy.set("attack_damage", 0)


func _door_is_open() -> bool:
	var door := get_node_or_null("Door")
	return door != null and door.get("is_open") == true


func _configure_level_camera() -> void:
	var camera := _get_camera()
	if not camera:
		return

	_camera_bounds = _get_camera_bounds()
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.limit_enabled = false
	camera.zoom = Vector2.ONE * camera_max_zoom
	camera.global_position = _clamp_camera_position_to_bounds(
		player.global_position,
		get_viewport_rect().size,
		camera.zoom
	)


func _update_level_camera(delta: float) -> void:
	var camera := _get_camera()
	if not camera or not player:
		return

	var player_pos := player.global_position
	var shadow_pos := player_pos
	if shadow:
		shadow_pos = shadow.global_position

	var target_position := player_pos.lerp(shadow_pos, camera_shadow_weight)
	var viewport_size := get_viewport_rect().size
	var target_zoom := camera_max_zoom

	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var span := (player_pos - shadow_pos).abs() + (camera_padding * 2.0)
		var fit_zoom_x := viewport_size.x / maxf(span.x, 1.0)
		var fit_zoom_y := viewport_size.y / maxf(span.y, 1.0)
		target_zoom = clampf(minf(fit_zoom_x, fit_zoom_y), camera_min_zoom, camera_max_zoom)
		target_zoom = _clamp_camera_zoom_to_bounds(target_zoom, viewport_size)

		if _key_reveal_time_remaining > 0.0 and key is Node2D:
			var key_pos := (key as Node2D).global_position
			target_position = player_pos.lerp(key_pos, 0.5)
			var reveal_span := (player_pos - key_pos).abs() + (camera_padding * 2.0)
			var reveal_zoom_x := viewport_size.x / maxf(reveal_span.x, 1.0)
			var reveal_zoom_y := viewport_size.y / maxf(reveal_span.y, 1.0)
			target_zoom = clampf(minf(reveal_zoom_x, reveal_zoom_y), camera_min_zoom, camera_max_zoom)
			target_zoom = _clamp_camera_zoom_to_bounds(target_zoom, viewport_size)

	var position_weight := clampf(delta * camera_position_smoothing, 0.0, 1.0)
	var zoom_weight := clampf(delta * camera_zoom_smoothing, 0.0, 1.0)
	var next_zoom := camera.zoom.lerp(Vector2.ONE * target_zoom, zoom_weight)
	var clamped_target_position := _clamp_camera_position_to_bounds(target_position, viewport_size, next_zoom)
	camera.global_position = camera.global_position.lerp(clamped_target_position, position_weight)
	camera.global_position = _clamp_camera_position_to_bounds(camera.global_position, viewport_size, next_zoom)
	camera.zoom = next_zoom


func _get_camera() -> Camera2D:
	if not player:
		return null

	return player.get_node_or_null("Camera2D") as Camera2D


func _get_camera_bounds() -> Rect2:
	var bounds := Rect2()
	var found_bounds := false

	for node_name in ["TileMapPlayer", "TileMapShadow"]:
		var tilemap := get_node_or_null(node_name) as TileMap
		if not tilemap:
			continue

		var tilemap_bounds := _get_tilemap_bounds(tilemap, true)
		if tilemap_bounds.size == Vector2.ZERO:
			continue

		if not found_bounds:
			bounds = tilemap_bounds
			found_bounds = true
		else:
			bounds = bounds.merge(tilemap_bounds)

	return bounds


func _get_floor_point(tilemap: TileMap, stand_cell: Vector2i) -> Vector2:
	var tile_size := tilemap.tile_set.tile_size
	var stand_center_local := tilemap.map_to_local(stand_cell)
	var floor_local := stand_center_local + Vector2(0.0, float(tile_size.y) * 0.5)
	return tilemap.to_global(floor_local)


func _clamp_camera_zoom_to_bounds(requested_zoom: float, viewport_size: Vector2) -> float:
	if _camera_bounds.size == Vector2.ZERO or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return requested_zoom

	var bounds_zoom_x := viewport_size.x / maxf(_camera_bounds.size.x, 1.0)
	var bounds_zoom_y := viewport_size.y / maxf(_camera_bounds.size.y, 1.0)
	var min_bounds_zoom := maxf(bounds_zoom_x, bounds_zoom_y)
	return clampf(maxf(requested_zoom, min_bounds_zoom), camera_min_zoom, camera_max_zoom)


func _clamp_camera_position_to_bounds(position: Vector2, viewport_size: Vector2, zoom: Vector2) -> Vector2:
	if _camera_bounds.size == Vector2.ZERO or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return position

	var visible_size := Vector2(
		viewport_size.x / maxf(zoom.x, 0.0001),
		viewport_size.y / maxf(zoom.y, 0.0001)
	)
	var half_view := visible_size * 0.5
	var bounds_center := _camera_bounds.get_center()

	var clamped_x := bounds_center.x
	if _camera_bounds.size.x > visible_size.x:
		clamped_x = clampf(position.x, _camera_bounds.position.x + half_view.x, _camera_bounds.end.x - half_view.x)

	var clamped_y := bounds_center.y
	if _camera_bounds.size.y > visible_size.y:
		clamped_y = clampf(position.y, _camera_bounds.position.y + half_view.y, _camera_bounds.end.y - half_view.y)

	return Vector2(clamped_x, clamped_y)


func _lower_door_platform_section() -> void:
	if door_platform_drop_rows == 0:
		return

	var tilemap := get_node_or_null("TileMapPlayer") as TileMap
	if not tilemap or tilemap.tile_set == null:
		return

	_move_platform_tiles(tilemap, DOOR_PLATFORM_TILES, door_platform_drop_rows)
	var drop_offset := _get_tilemap_drop_offset(tilemap, door_platform_drop_rows)

	var door := get_node_or_null("Door") as Node2D
	if door:
		door.position += drop_offset

	var door_blackness := get_node_or_null("DoorBlackness") as Node2D
	if door_blackness:
		door_blackness.position += drop_offset

func _lower_key_platform_section() -> void:
	if key_platform_drop_rows == 0:
		return

	var tilemap := get_node_or_null("TileMapPlayer") as TileMap
	if not tilemap or tilemap.tile_set == null:
		return

	_move_platform_tiles(tilemap, KEY_PLATFORM_TILES, key_platform_drop_rows)
	var drop_offset := _get_tilemap_drop_offset(tilemap, key_platform_drop_rows)

	if key is Node2D:
		(key as Node2D).position += drop_offset

func _move_platform_tiles(tilemap: TileMap, platform_tiles: Array, drop_rows: int) -> void:
	var drop_cells := Vector2i(0, drop_rows)
	for coords in platform_tiles:
		for layer in tilemap.get_layers_count():
			var source_id := tilemap.get_cell_source_id(layer, coords)
			if source_id == -1:
				continue

			var atlas_coords := tilemap.get_cell_atlas_coords(layer, coords)
			var alternative_tile := tilemap.get_cell_alternative_tile(layer, coords)
			tilemap.erase_cell(layer, coords)
			tilemap.set_cell(layer, coords + drop_cells, source_id, atlas_coords, alternative_tile)

func _get_tilemap_drop_offset(tilemap: TileMap, drop_rows: int) -> Vector2:
	return Vector2(0.0, tilemap.tile_set.tile_size.y * tilemap.scale.y * drop_rows)


func _fix_level_one_shadow_gap() -> void:
	if name != "LevelOne":
		return

	var player_tilemap := get_node_or_null("TileMapPlayer") as TileMap
	var shadow_tilemap := get_node_or_null("TileMapShadow") as TileMap
	if not player_tilemap or not shadow_tilemap:
		return

	for layer in [1, 2]:
		_copy_tilemap_region(
			player_tilemap,
			shadow_tilemap,
			layer,
			LEVEL_ONE_SHADOW_GAP_FIX_START,
			LEVEL_ONE_SHADOW_GAP_FIX_END
		)


func _setup_level_walls() -> void:
	var level_bounds := _get_level_bounds()
	if level_bounds.size == Vector2.ZERO:
		return

	_fall_reset_y = level_bounds.end.y + fall_reset_margin

	var walls_root := get_node_or_null("LevelWalls") as Node2D
	if not walls_root:
		walls_root = Node2D.new()
		walls_root.name = "LevelWalls"
		add_child(walls_root)

	var wall_height := level_bounds.size.y + (level_wall_vertical_padding * 2.0)
	var wall_size := Vector2(level_wall_thickness, wall_height)
	var center_y := level_bounds.get_center().y
	var shadow_left_edge := level_bounds.position.x - shadow_wall_extra_margin
	var shadow_right_edge := level_bounds.end.x + shadow_wall_extra_margin

	_upsert_wall(
		walls_root,
		"PlayerLeftWall",
		Vector2(level_bounds.position.x - (level_wall_thickness * 0.5), center_y),
		wall_size,
		PLAYER_WALL_LAYER
	)
	_upsert_wall(
		walls_root,
		"PlayerRightWall",
		Vector2(level_bounds.end.x + (level_wall_thickness * 0.5), center_y),
		wall_size,
		PLAYER_WALL_LAYER
	)
	_upsert_wall(
		walls_root,
		"ShadowLeftWall",
		Vector2(shadow_left_edge - (level_wall_thickness * 0.5), center_y),
		wall_size,
		SHADOW_WALL_LAYER
	)
	_upsert_wall(
		walls_root,
		"ShadowRightWall",
		Vector2(shadow_right_edge + (level_wall_thickness * 0.5), center_y),
		wall_size,
		SHADOW_WALL_LAYER
	)

	if shadow and shadow.has_method("set_horizontal_bounds"):
		shadow.call("set_horizontal_bounds", shadow_left_edge, shadow_right_edge)


func _upsert_wall(parent: Node, wall_name: String, world_position: Vector2, wall_size: Vector2, collision_layer: int) -> void:
	var wall := parent.get_node_or_null(wall_name) as StaticBody2D
	if not wall:
		wall = StaticBody2D.new()
		wall.name = wall_name
		parent.add_child(wall)

	wall.top_level = true
	wall.global_position = world_position
	wall.collision_layer = collision_layer
	wall.collision_mask = 0

	var collision_shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		wall.add_child(collision_shape)

	var shape := collision_shape.shape as RectangleShape2D
	if not shape:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape

	shape.size = wall_size
	collision_shape.position = Vector2.ZERO


func _copy_tilemap_region(source_tilemap: TileMap, target_tilemap: TileMap, layer: int, start_cell: Vector2i, end_cell: Vector2i) -> void:
	for y in range(start_cell.y, end_cell.y + 1):
		for x in range(start_cell.x, end_cell.x + 1):
			var cell := Vector2i(x, y)
			var source_id := source_tilemap.get_cell_source_id(layer, cell)
			if source_id == -1:
				target_tilemap.erase_cell(layer, cell)
				continue

			target_tilemap.set_cell(
				layer,
				cell,
				source_id,
				source_tilemap.get_cell_atlas_coords(layer, cell),
				source_tilemap.get_cell_alternative_tile(layer, cell)
			)


func _reset_on_fall() -> bool:
	if not is_finite(_fall_reset_y):
		return false
	if not player or not shadow:
		return false
	if player.global_position.y <= _fall_reset_y and shadow.global_position.y <= _fall_reset_y:
		return false

	_swap_requested = false

	if player.has_method("reset_to_level_start"):
		player.call("reset_to_level_start", _player_start_position, true)
	else:
		player.global_position = _player_start_position
		player.velocity = Vector2.ZERO

	if shadow.has_method("reset_to_level_start"):
		shadow.call("reset_to_level_start", _shadow_start_position)
	else:
		shadow.global_position = _shadow_start_position
		shadow.velocity = Vector2.ZERO
		if shadow.has_method("reset_queue"):
			shadow.call("reset_queue")

	if enemy:
		if enemy.has_method("reset_to_level_start"):
			enemy.call("reset_to_level_start", _enemy_start_position)
		else:
			enemy.global_position = _enemy_start_position
			enemy.velocity = Vector2.ZERO

	if key is Node2D:
		if key.has_method("reset_to_level_start"):
			key.call("reset_to_level_start", _key_start_position, false)
		else:
			(key as Node2D).global_position = _key_start_position
			if key.has_method("set_available"):
				key.call("set_available", false)

	var camera := _get_camera()
	if camera:
		camera.global_position = _clamp_camera_position_to_bounds(
			player.global_position,
			get_viewport_rect().size,
			camera.zoom
		)

	_key_reveal_time_remaining = 0.0

	if _is_tutorial_level():
		_restart_tutorial()

	return true


func _get_level_bounds() -> Rect2:
	var bounds := Rect2()
	var found_bounds := false

	for node_name in ["TileMapPlayer", "TileMapShadow"]:
		var tilemap := get_node_or_null(node_name) as TileMap
		if not tilemap:
			continue

		var tilemap_bounds := _get_tilemap_bounds(tilemap)
		if tilemap_bounds.size == Vector2.ZERO:
			continue

		if not found_bounds:
			bounds = tilemap_bounds
			found_bounds = true
		else:
			bounds = bounds.merge(tilemap_bounds)

	return bounds


func _get_tilemap_bounds(tilemap: TileMap, include_all_layers: bool = false) -> Rect2:
	if tilemap.tile_set == null:
		return Rect2()

	var used_cells: Array[Vector2i] = []
	if include_all_layers:
		for layer in tilemap.get_layers_count():
			used_cells.append_array(tilemap.get_used_cells(layer))
	else:
		used_cells = tilemap.get_used_cells(1)
		if used_cells.is_empty():
			used_cells = tilemap.get_used_cells(0)

	if used_cells.is_empty():
		return Rect2()

	var min_cell := used_cells[0] as Vector2i
	var max_cell := min_cell
	for cell_variant in used_cells:
		var cell := cell_variant as Vector2i
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)

	var tile_size := Vector2(tilemap.tile_set.tile_size)
	var top_left_local := tilemap.map_to_local(min_cell) - (tile_size * 0.5)
	var bottom_right_local := tilemap.map_to_local(max_cell) + (tile_size * 0.5)

	var top_left := tilemap.to_global(top_left_local)
	var bottom_right := tilemap.to_global(bottom_right_local)

	return Rect2(top_left, bottom_right - top_left).abs()

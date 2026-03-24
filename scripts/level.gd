# MainScene.gd
extends Node2D

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

var _swap_requested := false

func _ready() -> void:
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	if enemy and enemy.has_signal("defeated"):
		if not enemy.defeated.is_connected(_on_enemy_defeated):
			enemy.defeated.connect(_on_enemy_defeated)

	if key and key.has_method("set_available"):
		key.call("set_available", false)

	_configure_level_camera()

func _unhandled_input(event):
	if event.is_action_pressed("swap_sprites"):
		_swap_requested = true

func _physics_process(delta):
	if _swap_requested:
		_swap_requested = false
		swap_positions()

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

func _on_enemy_defeated() -> void:
	if key and key.has_method("set_available"):
		key.call("set_available", true)

func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _configure_level_camera() -> void:
	var camera := _get_camera()
	if not camera:
		return

	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.limit_enabled = false
	camera.global_position = player.global_position
	camera.zoom = Vector2.ONE * camera_max_zoom


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

	var position_weight := clampf(delta * camera_position_smoothing, 0.0, 1.0)
	var zoom_weight := clampf(delta * camera_zoom_smoothing, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target_position, position_weight)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, zoom_weight)


func _get_camera() -> Camera2D:
	if not player:
		return null

	return player.get_node_or_null("Camera2D") as Camera2D

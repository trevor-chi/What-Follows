# MainScene.gd
extends Node2D

const PLAYER_WALL_LAYER := 8
const SHADOW_WALL_LAYER := 16

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
@export var level_wall_thickness := 128.0
@export var level_wall_vertical_padding := 256.0
@export var shadow_wall_extra_margin := 0.0

var _swap_requested := false

func _ready() -> void:
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	if enemy and enemy.has_signal("defeated"):
		if not enemy.defeated.is_connected(_on_enemy_defeated):
			enemy.defeated.connect(_on_enemy_defeated)

	if key and key.has_method("set_available"):
		key.call("set_available", false)

	_setup_level_walls()
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


func _setup_level_walls() -> void:
	var level_bounds := _get_level_bounds()
	if level_bounds.size == Vector2.ZERO:
		return

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


func _get_tilemap_bounds(tilemap: TileMap) -> Rect2:
	if tilemap.tile_set == null:
		return Rect2()

	var used_cells := tilemap.get_used_cells(1)
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

extends RefCounted
class_name LevelBuilder

const BACKGROUND_TILE_LAYER := 0
const PLAYER_TILE_LAYER := 1
const FOREGROUND_TILE_LAYER := 2
const MAX_WALK_STEP_DOWN := 1
const MAX_JUMP_UP_CELLS := 4
const MAX_DROP_DOWN_CELLS := 6
const MAX_JUMP_ACROSS_CELLS := 6
const MAX_DROP_ACROSS_CELLS := 2

const PLAYER_JUMP_VELOCITY := -750.0
const PLAYER_GRAVITY := 1100.0
const MAX_JUMP_HORIZONTAL_SPEED := 360.0
const MAX_DROP_HORIZONTAL_SPEED := 260.0
const PLAYER_BODY_WIDTH := 30.0
const PLAYER_BODY_HEIGHT := 93.6
const PLATFORM_ATLAS := Vector2i(5, 4)
const HAZARD_ROUTE_MARGIN := 8.0
const BACKDROP_SOURCE_ID := 1
const BACKDROP_TOP_ATLAS := Vector2i(0, 4)
const BACKDROP_LOWER_ATLAS := Vector2i(0, 0)
const BACKDROP_REPEAT_WIDTH := 18
const BACKDROP_ROW_STEP := 4
const BACKDROP_TOP_ROW_COUNT := 4
const BACKDROP_LOWER_ROW_COUNT := 4
const BACKDROP_LEFT_MARGIN := 9
const BACKDROP_TOP_OFFSET := 23
const BACKDROP_LOWER_OFFSET := 7
const DECOR_SOURCE_ID := 0
const SMALL_TREE_ATLAS := Vector2i(0, 5)
const ROCK_A_ATLAS := Vector2i(3, 3)
const ROCK_B_ATLAS := Vector2i(3, 4)
const SMALL_TREE_SIZE := Vector2i(4, 4)
const SCENIC_EDGE_PADDING := 10


func build_level(template_scene: PackedScene, chunk_scenes: Array[PackedScene], save_path: String) -> Error:
	if template_scene == null:
		return ERR_INVALID_PARAMETER
	if chunk_scenes.is_empty():
		return ERR_INVALID_PARAMETER

	var level_root := template_scene.instantiate()
	if level_root == null:
		return ERR_CANT_CREATE

	if level_root is Node2D:
		(level_root as Node2D).scale = Vector2.ONE

	var player_tilemap := level_root.get_node_or_null("TileMapPlayer") as TileMap
	var shadow_tilemap := level_root.get_node_or_null("TileMapShadow") as TileMap
	if player_tilemap == null or shadow_tilemap == null:
		level_root.free()
		return ERR_DOES_NOT_EXIST

	player_tilemap.clear()
	shadow_tilemap.clear()

	var has_player_spawn := false
	var has_shadow_spawn := false
	var has_enemy_spawn := false
	var has_key_spawn := false
	var has_door_spawn := false
	var has_shadow_area_spawn := false

	var player_spawn_cell := Vector2i.ZERO
	var shadow_spawn_cell := Vector2i.ZERO
	var enemy_spawn_cell := Vector2i.ZERO
	var key_spawn_cell := Vector2i.ZERO
	var door_spawn_cell := Vector2i.ZERO
	var shadow_area_spawn_cell := Vector2i.ZERO

	var previous_exit_global := Vector2i.ZERO
	var has_previous_exit := false

	for chunk_scene in chunk_scenes:
		if chunk_scene == null:
			continue

		var chunk := chunk_scene.instantiate() as LevelChunk
		if chunk == null:
			continue

		chunk.prepare_chunk()
		var validation_errors: PackedStringArray = chunk.get_validation_errors()
		if not validation_errors.is_empty():
			printerr(validation_errors[0])
			chunk.free()
			level_root.free()
			return ERR_INVALID_DATA

		var origin := Vector2i.ZERO
		if has_previous_exit:
			origin = _get_chunk_origin(previous_exit_global, chunk)
			var entry_global := origin + chunk.entry_cell
			if entry_global != previous_exit_global + Vector2i.RIGHT:
				chunk.free()
				level_root.free()
				return ERR_INVALID_DATA
			if not _is_supported_actor_cell(player_tilemap, previous_exit_global) or not chunk.has_supported_player_cell(chunk.entry_cell):
				chunk.free()
				level_root.free()
				return ERR_INVALID_DATA
		else:
			if not chunk.has_supported_player_cell(chunk.player_spawn_cell) or not chunk.has_supported_shadow_cell(chunk.shadow_spawn_cell):
				chunk.free()
				level_root.free()
				return ERR_INVALID_DATA

		chunk.stamp_into(player_tilemap, shadow_tilemap, origin)

		if not has_player_spawn and chunk.has_marker_cell(chunk.player_spawn_cell):
			player_spawn_cell = origin + chunk.player_spawn_cell
			has_player_spawn = true
		if not has_shadow_spawn and chunk.has_marker_cell(chunk.shadow_spawn_cell):
			shadow_spawn_cell = origin + chunk.shadow_spawn_cell
			has_shadow_spawn = true
		if not has_enemy_spawn and chunk.has_marker_cell(chunk.enemy_spawn_cell):
			enemy_spawn_cell = origin + chunk.enemy_spawn_cell
			has_enemy_spawn = true
		if not has_key_spawn and chunk.has_marker_cell(chunk.key_spawn_cell):
			key_spawn_cell = origin + chunk.key_spawn_cell
			has_key_spawn = true
		if not has_door_spawn and chunk.has_marker_cell(chunk.door_spawn_cell):
			door_spawn_cell = origin + chunk.door_spawn_cell
			has_door_spawn = true
		if not has_shadow_area_spawn and chunk.has_marker_cell(chunk.shadow_area_spawn_cell):
			shadow_area_spawn_cell = origin + chunk.shadow_area_spawn_cell
			has_shadow_area_spawn = true

		previous_exit_global = origin + chunk.exit_cell
		has_previous_exit = true
		chunk.free()

	if not has_player_spawn or not has_shadow_spawn or not has_enemy_spawn or not has_key_spawn or not has_door_spawn:
		level_root.free()
		return ERR_INVALID_DATA

	if not _is_supported_actor_cell(player_tilemap, player_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _is_supported_actor_cell(shadow_tilemap, shadow_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _is_supported_actor_cell(player_tilemap, enemy_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _is_supported_actor_cell(player_tilemap, key_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _is_supported_actor_cell(player_tilemap, door_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if has_shadow_area_spawn and not _is_supported_actor_cell(player_tilemap, shadow_area_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA

	if not _place_named_node_on_cell(level_root, "Player", player_tilemap, player_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _place_named_node_on_cell(level_root, "Shadow", shadow_tilemap, shadow_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _place_named_node_on_cell(level_root, "Enemy", player_tilemap, enemy_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _place_named_node_on_cell(level_root, "Key", player_tilemap, key_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if not _place_door(level_root, player_tilemap, door_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA
	if has_shadow_area_spawn and not _place_named_node_on_cell(level_root, "ShadowArea", player_tilemap, shadow_area_spawn_cell):
		level_root.free()
		return ERR_INVALID_DATA

	var progression_valid := _validate_progression(player_tilemap, player_spawn_cell, enemy_spawn_cell, key_spawn_cell, door_spawn_cell)
	if not progression_valid:
		level_root.free()
		return ERR_INVALID_DATA

	if has_shadow_area_spawn:
		var blocked_cells := _collect_shadow_area_blocked_cells(level_root, player_tilemap)
		if not blocked_cells.is_empty() and not _validate_progression(player_tilemap, player_spawn_cell, enemy_spawn_cell, key_spawn_cell, door_spawn_cell, blocked_cells):
			_disable_shadow_area(level_root)
	else:
		_disable_shadow_area(level_root)

	_paint_template_backdrop(player_tilemap, shadow_tilemap)
	_add_scenic_small_trees(
		player_tilemap,
		[player_spawn_cell, enemy_spawn_cell, key_spawn_cell, door_spawn_cell]
	)

	var output_dir := save_path.get_base_dir()
	if output_dir.is_empty():
		output_dir = "res://generated_levels"
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if make_dir_error != OK:
		level_root.free()
		return make_dir_error

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(level_root)
	level_root.free()
	if pack_error != OK:
		return pack_error

	return ResourceSaver.save(packed_scene, save_path)


func _place_named_node_on_cell(level_root: Node, node_name: String, tilemap: TileMap, stand_cell: Vector2i) -> bool:
	var node := level_root.get_node_or_null(node_name) as Node2D
	if node == null:
		return false
	return _place_node_on_cell(node, tilemap, stand_cell)


func _place_door(level_root: Node, tilemap: TileMap, stand_cell: Vector2i) -> bool:
	var door := level_root.get_node_or_null("Door") as Node2D
	if door == null:
		return false

	var previous_position := door.position
	if not _place_node_on_cell(door, tilemap, stand_cell):
		return false

	var delta := door.position - previous_position
	var door_blackness := level_root.get_node_or_null("DoorBlackness") as Node2D
	if door_blackness:
		door_blackness.position += delta

	return true


func _place_node_on_cell(node: Node2D, tilemap: TileMap, stand_cell: Vector2i) -> bool:
	var floor_point := _get_floor_point(tilemap, stand_cell)
	var bottom_offset := _get_bottom_center_offset(node)
	if not is_finite(bottom_offset.x) or not is_finite(bottom_offset.y):
		return false

	node.global_position = floor_point - bottom_offset
	return true


func _get_floor_point(tilemap: TileMap, stand_cell: Vector2i) -> Vector2:
	var tile_size := tilemap.tile_set.tile_size
	var stand_center_local := tilemap.map_to_local(stand_cell)
	var floor_local := stand_center_local + Vector2(0.0, float(tile_size.y) * 0.5)
	return tilemap.to_global(floor_local)


func _get_bottom_center_offset(node: Node2D) -> Vector2:
	var collision_shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return Vector2.ZERO

	var bottom_local := collision_shape.position
	if collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		bottom_local += Vector2(0.0, (rectangle.size.y * collision_shape.scale.y) * 0.5)
	elif collision_shape.shape is CapsuleShape2D:
		var capsule := collision_shape.shape as CapsuleShape2D
		bottom_local += Vector2(0.0, (capsule.height * collision_shape.scale.y) * 0.5)
	elif collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		bottom_local += Vector2(0.0, circle.radius * collision_shape.scale.y)

	var bottom_global := node.to_global(bottom_local)
	return bottom_global - node.global_position


func _disable_shadow_area(level_root: Node) -> void:
	var shadow_area := level_root.get_node_or_null("ShadowArea") as Area2D
	if shadow_area == null:
		return

	shadow_area.visible = false
	shadow_area.monitoring = false
	var collision_shape := shadow_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.set_deferred("disabled", true)


func _add_scenic_small_trees(tilemap: TileMap, avoid_cells: Array[Vector2i]) -> void:
	var standable := _collect_standable_cells(tilemap)
	if standable.is_empty():
		return

	var candidates := _collect_flat_surface_candidates(tilemap, standable, avoid_cells)
	if candidates.is_empty():
		return

	var used_ranges := _collect_existing_small_tree_ranges(tilemap)
	var rect := tilemap.get_used_rect()
	var width := maxi(rect.size.x, 1)
	var anchors := [
		rect.position.x + int(round(width * 0.22)),
		rect.position.x + int(round(width * 0.50)),
		rect.position.x + int(round(width * 0.78)),
	]

	var existing_tree_count := used_ranges.size()
	var desired_tree_count := 3 if width <= 48 else 4
	var additional_tree_budget := maxi(0, desired_tree_count - existing_tree_count)
	var small_tree_budget := mini(additional_tree_budget, anchors.size())
	for i in range(small_tree_budget):
		var small_surface := _pick_surface_near_anchor(tilemap, candidates, used_ranges, anchors[i], 2, 2)
		if small_surface == Vector2i(-1, -1):
			continue
		var small_tree_origin := Vector2i(small_surface.x - 1, small_surface.y - 1)
		_place_midground_tree(tilemap, small_tree_origin)
		used_ranges.append(Vector2i(small_surface.x - 7, small_surface.x + 7))


func _collect_existing_small_tree_ranges(tilemap: TileMap) -> Array[Vector2i]:
	var used_ranges: Array[Vector2i] = []
	var midground_cells: Array[Vector2i] = tilemap.get_used_cells(PLAYER_TILE_LAYER)
	for cell in midground_cells:
		var atlas := tilemap.get_cell_atlas_coords(PLAYER_TILE_LAYER, cell)
		if atlas != SMALL_TREE_ATLAS:
			continue
		used_ranges.append(Vector2i(cell.x - 6, cell.x + 6))
	return used_ranges


func _paint_template_backdrop(player_tilemap: TileMap, shadow_tilemap: TileMap) -> void:
	var standable := _collect_standable_cells(player_tilemap)
	if standable.is_empty():
		return

	var primary_surface_y := _get_primary_surface_y(standable)
	var rect := player_tilemap.get_used_rect()
	var start_x := rect.position.x - BACKDROP_LEFT_MARGIN
	var end_x := rect.end.x + BACKDROP_REPEAT_WIDTH

	for x in range(start_x, end_x, BACKDROP_REPEAT_WIDTH):
		for row in range(BACKDROP_TOP_ROW_COUNT):
			var cell := Vector2i(x, primary_surface_y - BACKDROP_TOP_OFFSET + (row * BACKDROP_ROW_STEP))
			player_tilemap.set_cell(BACKGROUND_TILE_LAYER, cell, BACKDROP_SOURCE_ID, BACKDROP_TOP_ATLAS)
			shadow_tilemap.set_cell(BACKGROUND_TILE_LAYER, cell, BACKDROP_SOURCE_ID, BACKDROP_TOP_ATLAS)
		for row in range(BACKDROP_LOWER_ROW_COUNT):
			var cell := Vector2i(x, primary_surface_y - BACKDROP_LOWER_OFFSET + (row * BACKDROP_ROW_STEP))
			player_tilemap.set_cell(BACKGROUND_TILE_LAYER, cell, BACKDROP_SOURCE_ID, BACKDROP_LOWER_ATLAS)
			shadow_tilemap.set_cell(BACKGROUND_TILE_LAYER, cell, BACKDROP_SOURCE_ID, BACKDROP_LOWER_ATLAS)


func _get_primary_surface_y(standable: Dictionary) -> int:
	var counts_by_y := {}
	for stand_cell_variant in standable.keys():
		var stand_cell := stand_cell_variant as Vector2i
		counts_by_y[stand_cell.y] = int(counts_by_y.get(stand_cell.y, 0)) + 1

	var best_y := 0
	var best_count := -1
	for y_variant in counts_by_y.keys():
		var y := int(y_variant)
		var count := int(counts_by_y[y])
		if count > best_count or (count == best_count and y < best_y):
			best_y = y
			best_count = count
	return best_y


func _collect_flat_surface_candidates(tilemap: TileMap, standable: Dictionary, avoid_cells: Array[Vector2i]) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var cells: Array[Vector2i] = []
	for stand_cell_variant in standable.keys():
		cells.append(stand_cell_variant as Vector2i)

	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)

	for stand_cell in cells:
		if stand_cell.x <= SCENIC_EDGE_PADDING:
			continue
		if stand_cell.x >= tilemap.get_used_rect().end.x - SCENIC_EDGE_PADDING:
			continue
		if not _has_flat_run_global(tilemap, stand_cell, 2):
			continue
		var too_close := false
		for avoid in avoid_cells:
			if absi(avoid.x - stand_cell.x) <= 6:
				too_close = true
				break
		if too_close:
			continue
		candidates.append(stand_cell)

	return candidates


func _pick_surface_near_anchor(tilemap: TileMap, candidates: Array[Vector2i], used_ranges: Array[Vector2i], anchor_x: int, required_half_width: int, height_tolerance: int) -> Vector2i:
	var max_y := -99999
	for candidate in candidates:
		if _surface_range_is_free(candidate.x, used_ranges) and _has_flat_run_global(tilemap, candidate, required_half_width):
			max_y = maxi(max_y, candidate.y)

	var best := Vector2i(-1, -1)
	var best_score := INF

	for candidate in candidates:
		if not _surface_range_is_free(candidate.x, used_ranges):
			continue
		if not _has_flat_run_global(tilemap, candidate, required_half_width):
			continue
		if candidate.y < max_y - height_tolerance:
			continue
		var score := absf(float(candidate.x - anchor_x)) + (float(max_y - candidate.y) * 12.0)
		if score < best_score:
			best = candidate
			best_score = score

	return best


func _surface_range_is_free(x: int, used_ranges: Array[Vector2i]) -> bool:
	for used_range in used_ranges:
		if x >= used_range.x and x <= used_range.y:
			return false
	return true


func _place_story_prop(tilemap: TileMap, top_left: Vector2i, size: Vector2i, atlas: Vector2i) -> void:
	if top_left.y < 0:
		return
	if not _can_place_background_prop(tilemap, top_left, size):
		return
	tilemap.set_cell(BACKGROUND_TILE_LAYER, top_left, DECOR_SOURCE_ID, atlas)


func _place_midground_tree(tilemap: TileMap, top_left: Vector2i) -> void:
	if top_left.y < 0:
		return
	if not _can_place_midground_tree(tilemap, top_left, SMALL_TREE_SIZE):
		return
	tilemap.set_cell(PLAYER_TILE_LAYER, top_left, DECOR_SOURCE_ID, SMALL_TREE_ATLAS)


func _has_flat_run_global(tilemap: TileMap, stand_cell: Vector2i, half_width: int) -> bool:
	for x in range(stand_cell.x - half_width, stand_cell.x + half_width + 1):
		var current := Vector2i(x, stand_cell.y)
		if not _is_supported_actor_cell(tilemap, current):
			return false
	return true


func _can_place_background_prop(tilemap: TileMap, top_left: Vector2i, size: Vector2i) -> bool:
	var target_rect := Rect2i(top_left, size)
	for used_cell in tilemap.get_used_cells(BACKGROUND_TILE_LAYER):
		var atlas := tilemap.get_cell_atlas_coords(BACKGROUND_TILE_LAYER, used_cell)
		var existing_size := Vector2i.ONE
		if atlas == SMALL_TREE_ATLAS:
			existing_size = SMALL_TREE_SIZE
		elif atlas == ROCK_A_ATLAS or atlas == ROCK_B_ATLAS:
			existing_size = Vector2i(2, 1)
		if Rect2i(used_cell, existing_size).intersects(target_rect):
			return false
	return true


func _can_place_midground_tree(tilemap: TileMap, top_left: Vector2i, size: Vector2i) -> bool:
	var target_rect := Rect2i(top_left, size)
	for used_cell in tilemap.get_used_cells(PLAYER_TILE_LAYER):
		var atlas := tilemap.get_cell_atlas_coords(PLAYER_TILE_LAYER, used_cell)
		if atlas != SMALL_TREE_ATLAS:
			continue
		if Rect2i(used_cell, SMALL_TREE_SIZE).intersects(target_rect):
			return false
	return true


func _get_chunk_origin(previous_exit_global: Vector2i, chunk: LevelChunk) -> Vector2i:
	return Vector2i(
		previous_exit_global.x + 1 - chunk.entry_cell.x,
		previous_exit_global.y - chunk.entry_cell.y
	)


func _is_supported_actor_cell(tilemap: TileMap, cell: Vector2i) -> bool:
	return tilemap.get_cell_source_id(PLAYER_TILE_LAYER, cell) == -1 and tilemap.get_cell_source_id(PLAYER_TILE_LAYER, cell + Vector2i.DOWN) != -1


func _validate_progression(tilemap: TileMap, start_cell: Vector2i, enemy_cell: Vector2i, key_cell: Vector2i, door_cell: Vector2i, blocked_cells: Dictionary = {}) -> bool:
	var standable := _collect_standable_cells(tilemap)
	if standable.is_empty():
		return false

	if not standable.has(start_cell) or not standable.has(enemy_cell) or not standable.has(key_cell) or not standable.has(door_cell):
		return false
	if blocked_cells.has(start_cell) or blocked_cells.has(enemy_cell) or blocked_cells.has(key_cell) or blocked_cells.has(door_cell):
		return false

	if not _can_reach(tilemap, standable, blocked_cells, start_cell, enemy_cell):
		return false
	if not _can_reach(tilemap, standable, blocked_cells, enemy_cell, key_cell):
		return false
	if not _can_reach(tilemap, standable, blocked_cells, key_cell, door_cell):
		return false

	return true


func _collect_standable_cells(tilemap: TileMap) -> Dictionary:
	var standable := {}
	var used_cells: Array[Vector2i] = tilemap.get_used_cells(PLAYER_TILE_LAYER)
	for filled_cell in used_cells:
		var stand_cell := filled_cell + Vector2i.UP
		if tilemap.get_cell_source_id(PLAYER_TILE_LAYER, stand_cell) != -1:
			continue
		standable[stand_cell] = true
	return standable


func _collect_shadow_area_blocked_cells(level_root: Node, tilemap: TileMap) -> Dictionary:
	var shadow_area := level_root.get_node_or_null("ShadowArea") as Area2D
	if shadow_area == null or not shadow_area.visible:
		return {}

	var collision_shape := shadow_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return {}

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return {}

	var half_size := rectangle.size * 0.5
	var top_left := collision_shape.to_global(-half_size)
	var bottom_right := collision_shape.to_global(half_size)
	var hazard_rect := Rect2(top_left, bottom_right - top_left).abs().grow(HAZARD_ROUTE_MARGIN)

	var blocked := {}
	var standable := _collect_standable_cells(tilemap)
	for stand_cell_variant in standable.keys():
		var stand_cell := stand_cell_variant as Vector2i
		var floor_point := _get_floor_point(tilemap, stand_cell)
		var actor_rect := Rect2(
			floor_point.x - (PLAYER_BODY_WIDTH * 0.5),
			floor_point.y - PLAYER_BODY_HEIGHT,
			PLAYER_BODY_WIDTH,
			PLAYER_BODY_HEIGHT
		)
		if actor_rect.intersects(hazard_rect):
			blocked[stand_cell] = true

	return blocked


func _can_reach(tilemap: TileMap, standable: Dictionary, blocked_cells: Dictionary, start_cell: Vector2i, goal_cell: Vector2i) -> bool:
	if start_cell == goal_cell:
		return true

	var queue: Array[Vector2i] = [start_cell]
	var visited := {start_cell: true}

	while not queue.is_empty():
		var current := queue.pop_front() as Vector2i
		for next_cell in _get_reachable_neighbors(tilemap, standable, blocked_cells, current):
			if visited.has(next_cell):
				continue
			if next_cell == goal_cell:
				return true

			visited[next_cell] = true
			queue.append(next_cell)

	return false


func _get_reachable_neighbors(tilemap: TileMap, standable: Dictionary, blocked_cells: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var min_x := current.x - MAX_JUMP_ACROSS_CELLS
	var max_x := current.x + MAX_JUMP_ACROSS_CELLS
	var min_y := current.y - MAX_JUMP_UP_CELLS
	var max_y := current.y + MAX_DROP_DOWN_CELLS

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var candidate := Vector2i(x, y)
			if candidate == current or blocked_cells.has(candidate) or not standable.has(candidate):
				continue
			if _can_transition_between(tilemap, current, candidate):
				neighbors.append(candidate)

	return neighbors


func _can_transition_between(tilemap: TileMap, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var dx := to_cell.x - from_cell.x
	var dy := to_cell.y - from_cell.y
	var abs_dx := absi(dx)

	if abs_dx <= 1 and dy <= MAX_WALK_STEP_DOWN and dy >= -1:
		return true
	if dy == 0 and _has_contiguous_floor(tilemap, from_cell, to_cell):
		return true
	if dy > 0 and dy <= MAX_DROP_DOWN_CELLS and abs_dx <= MAX_DROP_ACROSS_CELLS:
		return _can_traverse_ballistically(tilemap, from_cell, to_cell, 0.0, MAX_DROP_HORIZONTAL_SPEED)
	if abs_dx > MAX_JUMP_ACROSS_CELLS:
		return false
	if dy < 0 and absi(dy) > MAX_JUMP_UP_CELLS:
		return false
	if dy > MAX_DROP_DOWN_CELLS:
		return false

	return _can_traverse_ballistically(tilemap, from_cell, to_cell, PLAYER_JUMP_VELOCITY, MAX_JUMP_HORIZONTAL_SPEED)


func _can_traverse_ballistically(tilemap: TileMap, from_cell: Vector2i, to_cell: Vector2i, initial_vertical_speed: float, max_horizontal_speed: float) -> bool:
	var start_floor := _get_floor_point(tilemap, from_cell)
	var end_floor := _get_floor_point(tilemap, to_cell)
	var delta := end_floor - start_floor
	var travel_time := _solve_travel_time(initial_vertical_speed, delta.y)
	if travel_time <= 0.0:
		return false

	var horizontal_speed := delta.x / travel_time
	if absf(horizontal_speed) > max_horizontal_speed:
		return false

	return _trajectory_is_clear(tilemap, start_floor, initial_vertical_speed, horizontal_speed, travel_time)


func _solve_travel_time(initial_vertical_speed: float, delta_y: float) -> float:
	var a := 0.5 * PLAYER_GRAVITY
	var b := initial_vertical_speed
	var c := -delta_y
	var discriminant := (b * b) - (4.0 * a * c)
	if discriminant < 0.0:
		return -1.0

	var sqrt_discriminant := sqrt(discriminant)
	var denominator := 2.0 * a
	if is_zero_approx(denominator):
		return -1.0

	var root_a := (-b - sqrt_discriminant) / denominator
	var root_b := (-b + sqrt_discriminant) / denominator
	var best_time := -1.0
	if root_a > 0.0:
		best_time = root_a
	if root_b > 0.0:
		best_time = maxf(best_time, root_b)

	return best_time


func _trajectory_is_clear(tilemap: TileMap, start_floor: Vector2, initial_vertical_speed: float, horizontal_speed: float, travel_time: float) -> bool:
	var distance := absf(horizontal_speed) * travel_time
	var sample_count := maxi(10, int(ceil(maxf(travel_time / 0.04, distance / 24.0))))

	for i in range(1, sample_count):
		var t := travel_time * (float(i) / float(sample_count))
		var bottom_point := start_floor + Vector2(
			horizontal_speed * t,
			(initial_vertical_speed * t) + (0.5 * PLAYER_GRAVITY * t * t)
		)
		var vertical_velocity := initial_vertical_speed + (PLAYER_GRAVITY * t)
		if _body_hits_blocker(tilemap, bottom_point, vertical_velocity):
			return false

	return true


func _body_hits_blocker(tilemap: TileMap, bottom_point: Vector2, vertical_velocity: float) -> bool:
	var inset := 2.0
	var body_rect := Rect2(
		bottom_point.x - (PLAYER_BODY_WIDTH * 0.5) + inset,
		bottom_point.y - PLAYER_BODY_HEIGHT + inset,
		maxf(1.0, PLAYER_BODY_WIDTH - (inset * 2.0)),
		maxf(1.0, PLAYER_BODY_HEIGHT - (inset * 2.0))
	)
	var min_local := tilemap.to_local(body_rect.position)
	var max_local := tilemap.to_local(body_rect.position + body_rect.size)
	var min_cell := tilemap.local_to_map(min_local)
	var max_cell := tilemap.local_to_map(max_local)

	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if tilemap.get_cell_source_id(PLAYER_TILE_LAYER, cell) == -1:
				continue
			if _is_platform_cell(tilemap, cell) and vertical_velocity <= 0.0:
				continue
			return true

	return false


func _is_platform_cell(tilemap: TileMap, cell: Vector2i) -> bool:
	return tilemap.get_cell_atlas_coords(PLAYER_TILE_LAYER, cell) == PLATFORM_ATLAS


func _has_contiguous_floor(tilemap: TileMap, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if from_cell.y != to_cell.y:
		return false

	var step := 1 if to_cell.x >= from_cell.x else -1
	for x in range(from_cell.x, to_cell.x + step, step):
		var cell := Vector2i(x, from_cell.y)
		if not _is_supported_actor_cell(tilemap, cell):
			return false
	return true

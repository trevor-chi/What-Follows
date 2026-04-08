@tool
extends Node2D
class_name LevelChunk

const INVALID_CELL := Vector2i(-1, -1)
const BACKGROUND_TILE_LAYER := 0
const PLAYER_TILE_LAYER := 1
const SHADOW_TILE_LAYER := 1
const FOREGROUND_TILE_LAYER := 2
const BACKGROUND_SOURCE_ID := 1
const DECOR_SOURCE_ID := 0
const PLAYER_SOLID_ATLAS := Vector2i(0, 9)
const PLAYER_PLATFORM_ATLAS := Vector2i(5, 4)
const SHADOW_SOLID_ATLAS := Vector2i(0, 9)
const SHADOW_PLATFORM_ATLAS := Vector2i(5, 4)
const SMALL_TREE_ATLAS := Vector2i(0, 5)
const LARGE_TREE_ATLAS := Vector2i(11, 0)
const SMALL_TREE_SIZE := Vector2i(4, 4)
const LARGE_TREE_SIZE := Vector2i(7, 9)
const SHRUB_A_ATLAS := Vector2i(7, 5)
const SHRUB_B_ATLAS := Vector2i(7, 6)
const SHRUB_SIZE := Vector2i(3, 1)
const ROCK_A_ATLAS := Vector2i(3, 3)
const ROCK_B_ATLAS := Vector2i(3, 4)
const ROCK_SIZE := Vector2i(2, 1)
const GRASS_STRIP_ATLAS := Vector2i(4, 8)
const GRASS_STRIP_SIZE := Vector2i(5, 1)
const SURFACE_SINGLE_ATLAS := Vector2i(2, 9)
const SURFACE_LEFT_ATLAS := Vector2i(1, 9)
const SURFACE_RIGHT_ATLAS := Vector2i(3, 9)
const SURFACE_CENTER_ATLAS := Vector2i(7, 9)
const SURFACE_CENTER_ACCENT_ATLAS := Vector2i(5, 9)
const SHALLOW_FILL_ATLAS := Vector2i(0, 9)
const DEEP_FILL_PRIMARY_ATLAS := Vector2i(0, 9)
const DEEP_FILL_SECONDARY_ATLAS := Vector2i(15, 9)
const FILL_ACCENT_ATLAS := Vector2i(5, 9)
const BACKDROP_SEGMENTS := [
	{"cell": Vector2i(0, 0), "atlas": Vector2i(0, 0)},
	{"cell": Vector2i(0, 4), "atlas": Vector2i(0, 4)},
	{"cell": Vector2i(0, 8), "atlas": Vector2i(0, 8)},
]
const BACKDROP_REPEAT_WIDTH := 18

@export var chunk_id := ""
@export_enum("start", "path", "combat", "reward", "exit") var category := "path"
@export_range(1, 10, 1) var difficulty := 1
@export_range(1, 20, 1) var selection_weight := 1
@export_range(4, 128, 1) var width_in_cells := 20

@export var paint_default_backdrop := false
@export var auto_background_story := true
@export var auto_surface_details := false
@export var player_solid_rects: Array[Rect2i] = []
@export var player_platform_rects: Array[Rect2i] = []
@export var shadow_solid_rects: Array[Rect2i] = []
@export var shadow_platform_rects: Array[Rect2i] = []
@export var small_tree_cells: Array[Vector2i] = []
@export var large_tree_cells: Array[Vector2i] = []
@export var shrub_a_cells: Array[Vector2i] = []
@export var shrub_b_cells: Array[Vector2i] = []
@export var rock_a_cells: Array[Vector2i] = []
@export var rock_b_cells: Array[Vector2i] = []
@export var grass_strip_cells: Array[Vector2i] = []

@export var entry_cell := Vector2i(0, 9)
@export var exit_cell := Vector2i(19, 9)
@export var player_spawn_cell := Vector2i(2, 9)
@export var shadow_spawn_cell := Vector2i(1, 9)
@export var enemy_spawn_cell := INVALID_CELL
@export var key_spawn_cell := INVALID_CELL
@export var door_spawn_cell := INVALID_CELL
@export var shadow_area_spawn_cell := INVALID_CELL

func _ready() -> void:
	prepare_chunk()


func prepare_chunk() -> void:
	var player_tilemap := get_node_or_null("TileMapPlayerChunk") as TileMap
	if player_tilemap:
		player_tilemap.clear()
		_paint_backdrop(player_tilemap, Vector2i.ZERO)
		_paint_solid_terrain(player_tilemap, PLAYER_TILE_LAYER, player_solid_rects, false, Vector2i.ZERO)
		_paint_rects(player_tilemap, PLAYER_TILE_LAYER, player_platform_rects, PLAYER_PLATFORM_ATLAS)
		_paint_decorations(player_tilemap, Vector2i.ZERO)

	var shadow_tilemap := get_node_or_null("TileMapShadowChunk") as TileMap
	if shadow_tilemap:
		shadow_tilemap.clear()
		_paint_backdrop(shadow_tilemap, Vector2i.ZERO)
		_paint_solid_terrain(shadow_tilemap, SHADOW_TILE_LAYER, shadow_solid_rects, true, Vector2i.ZERO)
		_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, shadow_platform_rects, SHADOW_PLATFORM_ATLAS)

	_sync_marker_positions()


func stamp_into(player_tilemap: TileMap, shadow_tilemap: TileMap, offset: Vector2i) -> void:
	_paint_backdrop(player_tilemap, offset)
	_paint_solid_terrain(player_tilemap, PLAYER_TILE_LAYER, player_solid_rects, false, offset)
	_paint_rects(player_tilemap, PLAYER_TILE_LAYER, _offset_rects(player_platform_rects, offset), PLAYER_PLATFORM_ATLAS)
	_paint_decorations(player_tilemap, offset)
	_paint_backdrop(shadow_tilemap, offset)
	_paint_solid_terrain(shadow_tilemap, SHADOW_TILE_LAYER, shadow_solid_rects, true, offset)
	_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, _offset_rects(shadow_platform_rects, offset), SHADOW_PLATFORM_ATLAS)


func has_marker_cell(cell: Vector2i) -> bool:
	return cell != INVALID_CELL


func get_world_position_in(tilemap: TileMap, cell: Vector2i, offset: Vector2i = Vector2i.ZERO) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell + offset))


func get_exit_height_delta() -> int:
	return exit_cell.y - entry_cell.y


func has_platform_navigation() -> bool:
	return not player_platform_rects.is_empty()


func has_gap_navigation() -> bool:
	return has_platform_navigation() or _get_max_ground_gap(player_solid_rects) >= 2


func has_vertical_navigation() -> bool:
	return absi(get_exit_height_delta()) >= 2 or _get_surface_height_count(player_solid_rects) >= 3


func get_challenge_score() -> int:
	var score := maxi(1, difficulty)
	if has_gap_navigation():
		score += 2
	if has_platform_navigation():
		score += 1
	if has_vertical_navigation():
		score += 2
	if player_solid_rects.size() >= 4:
		score += 1
	return score


func has_supported_player_cell(cell: Vector2i) -> bool:
	return _has_supported_player_cell(cell)


func has_supported_shadow_cell(cell: Vector2i) -> bool:
	return _has_supported_shadow_cell(cell)


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []

	if width_in_cells <= 0:
		errors.append("%s has an invalid width." % _describe_chunk())

	if not _has_supported_player_cell(entry_cell):
		errors.append("%s entry cell is not standable for the player." % _describe_chunk())
	if not _has_supported_player_cell(exit_cell):
		errors.append("%s exit cell is not standable for the player." % _describe_chunk())
	if not _has_supported_shadow_cell(entry_cell):
		errors.append("%s entry cell is not standable for the shadow." % _describe_chunk())
	if not _has_supported_shadow_cell(exit_cell):
		errors.append("%s exit cell is not standable for the shadow." % _describe_chunk())

	if has_marker_cell(player_spawn_cell) and not _has_supported_player_cell(player_spawn_cell):
		errors.append("%s player spawn is not standable." % _describe_chunk())
	if has_marker_cell(shadow_spawn_cell) and not _has_supported_shadow_cell(shadow_spawn_cell):
		errors.append("%s shadow spawn is not standable." % _describe_chunk())
	if has_marker_cell(enemy_spawn_cell) and not _has_supported_player_cell(enemy_spawn_cell):
		errors.append("%s enemy spawn is not on a supported cell." % _describe_chunk())
	if has_marker_cell(key_spawn_cell) and not _has_supported_player_cell(key_spawn_cell):
		errors.append("%s key spawn is not on a supported cell." % _describe_chunk())
	if has_marker_cell(door_spawn_cell) and not _has_supported_player_cell(door_spawn_cell):
		errors.append("%s door spawn is not on a supported cell." % _describe_chunk())
	if has_marker_cell(shadow_area_spawn_cell) and not _has_supported_player_cell(shadow_area_spawn_cell):
		errors.append("%s shadow area spawn is not on a supported cell." % _describe_chunk())

	return errors


func _paint_rects(tilemap: TileMap, layer: int, rects: Array[Rect2i], atlas_coords: Vector2i) -> void:
	for rect in rects:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				tilemap.set_cell(layer, Vector2i(x, y), 0, atlas_coords)


func _paint_solid_terrain(tilemap: TileMap, layer: int, rects: Array[Rect2i], shadow_style: bool, offset: Vector2i) -> void:
	var filled := _collect_filled_cells(rects, offset)
	for cell_variant in filled.keys():
		var cell := cell_variant as Vector2i
		var atlas := _get_solid_atlas_for_cell(cell, filled, shadow_style)
		tilemap.set_cell(layer, cell, 0, atlas)


func _paint_backdrop(tilemap: TileMap, offset: Vector2i) -> void:
	if not paint_default_backdrop:
		return

	var phase := _positive_mod(_hash_ints([_chunk_hash_seed(), offset.x, offset.y]), BACKDROP_REPEAT_WIDTH)
	for x in range(-phase, width_in_cells, BACKDROP_REPEAT_WIDTH):
		for segment in BACKDROP_SEGMENTS:
			var cell := (segment["cell"] as Vector2i) + Vector2i(x + offset.x, 0)
			var atlas := segment["atlas"] as Vector2i
			tilemap.set_cell(BACKGROUND_TILE_LAYER, cell, BACKGROUND_SOURCE_ID, atlas)


func _paint_decorations(tilemap: TileMap, offset: Vector2i) -> void:
	var terrain_filled := _collect_filled_cells(player_solid_rects, offset)
	_paint_tree_cells(tilemap, small_tree_cells, SMALL_TREE_ATLAS, offset, terrain_filled)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, shrub_a_cells, SHRUB_A_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, shrub_b_cells, SHRUB_B_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, grass_strip_cells, GRASS_STRIP_ATLAS, offset)
	if auto_background_story:
		_paint_auto_background_story(tilemap, offset)
	if auto_surface_details:
		_paint_auto_surface_details(tilemap, offset)


func _paint_cells(tilemap: TileMap, layer: int, cells: Array[Vector2i], atlas_coords: Vector2i, offset: Vector2i) -> void:
	var size := _get_prop_size(atlas_coords)
	for cell in cells:
		var target := cell + offset
		if not _can_place_prop(tilemap, layer, target, size):
			continue
		tilemap.set_cell(layer, target, DECOR_SOURCE_ID, atlas_coords)


func _paint_tree_cells(tilemap: TileMap, cells: Array[Vector2i], atlas_coords: Vector2i, offset: Vector2i, filled: Dictionary) -> void:
	var size := _get_prop_size(atlas_coords)
	for cell in cells:
		var target := cell + offset
		var support_y := _find_tree_support_y(target, size, filled)
		if support_y != -1:
			target.y = _get_tree_origin_y(support_y, atlas_coords, size)
		if not _can_place_tree(tilemap, target, size):
			continue
		tilemap.set_cell(PLAYER_TILE_LAYER, target, DECOR_SOURCE_ID, atlas_coords)


func _find_tree_support_y(top_left: Vector2i, size: Vector2i, filled: Dictionary) -> int:
	var support_y := -1
	var sample_start_x := top_left.x + 1
	var sample_end_x := top_left.x + size.x - 2
	for sample_x in range(sample_start_x, sample_end_x + 1):
		for y in range(top_left.y, top_left.y + size.y + 6):
			if not filled.has(Vector2i(sample_x, y)):
				continue
			if support_y == -1:
				support_y = y
			else:
				support_y = maxi(support_y, y)
			break
	return support_y


func _get_tree_origin_y(support_y: int, atlas_coords: Vector2i, size: Vector2i) -> int:
	if atlas_coords == SMALL_TREE_ATLAS:
		return support_y - (size.y - 2)
	if atlas_coords == LARGE_TREE_ATLAS:
		return support_y - (size.y - 1)
	return support_y - (size.y - 1)


func _paint_auto_surface_details(tilemap: TileMap, offset: Vector2i) -> void:
	var filled := _collect_filled_cells(player_solid_rects, offset)
	var reserved := _collect_reserved_cells(offset)
	var surface_cells := _collect_surface_cells(filled)
	var occupied_ranges: Array[Vector2i] = []

	for surface_cell in surface_cells:
		if _is_reserved_surface(surface_cell, reserved):
			continue
		if not _surface_range_is_free(surface_cell.x, occupied_ranges):
			continue

		if _has_flat_run(filled, surface_cell, 3) and _roll(surface_cell, 0, 0.16):
			if not _can_place_prop(tilemap, FOREGROUND_TILE_LAYER, surface_cell, GRASS_STRIP_SIZE):
				continue
			tilemap.set_cell(FOREGROUND_TILE_LAYER, surface_cell, DECOR_SOURCE_ID, GRASS_STRIP_ATLAS)
			occupied_ranges.append(Vector2i(surface_cell.x - 1, surface_cell.x + GRASS_STRIP_SIZE.x + 1))
			continue

		if _has_flat_run(filled, surface_cell, 3) and _roll(surface_cell, 1, 0.06):
			var shrub_atlas := SHRUB_A_ATLAS if _roll(surface_cell, 2, 0.5) else SHRUB_B_ATLAS
			if not _can_place_prop(tilemap, FOREGROUND_TILE_LAYER, surface_cell, SHRUB_SIZE):
				continue
			tilemap.set_cell(FOREGROUND_TILE_LAYER, surface_cell, DECOR_SOURCE_ID, shrub_atlas)
			occupied_ranges.append(Vector2i(surface_cell.x - 1, surface_cell.x + SHRUB_SIZE.x + 1))
			continue

		if _roll(surface_cell, 3, 0.04):
			var rock_atlas := ROCK_A_ATLAS if _roll(surface_cell, 4, 0.5) else ROCK_B_ATLAS
			if not _can_place_prop(tilemap, FOREGROUND_TILE_LAYER, surface_cell, ROCK_SIZE):
				continue
			tilemap.set_cell(FOREGROUND_TILE_LAYER, surface_cell, DECOR_SOURCE_ID, rock_atlas)
			occupied_ranges.append(Vector2i(surface_cell.x - 1, surface_cell.x + ROCK_SIZE.x + 1))


func _paint_auto_background_story(tilemap: TileMap, offset: Vector2i) -> void:
	return


func _offset_rects(rects: Array[Rect2i], offset: Vector2i) -> Array[Rect2i]:
	var shifted: Array[Rect2i] = []
	for rect in rects:
		shifted.append(Rect2i(rect.position + offset, rect.size))
	return shifted


func _sync_marker_positions() -> void:
	var player_tilemap := get_node_or_null("TileMapPlayerChunk") as TileMap
	if not player_tilemap:
		return

	_position_marker("Entry", player_tilemap, entry_cell)
	_position_marker("Exit", player_tilemap, exit_cell)
	_position_marker("PlayerSpawn", player_tilemap, player_spawn_cell)
	_position_marker("ShadowSpawn", player_tilemap, shadow_spawn_cell)
	_position_marker("EnemySpawn", player_tilemap, enemy_spawn_cell)
	_position_marker("KeySpawn", player_tilemap, key_spawn_cell)
	_position_marker("DoorSpawn", player_tilemap, door_spawn_cell)
	_position_marker("ShadowAreaSpawn", player_tilemap, shadow_area_spawn_cell)


func _position_marker(marker_name: String, tilemap: TileMap, cell: Vector2i) -> void:
	var marker := get_node_or_null("Markers/%s" % marker_name) as Marker2D
	if not marker:
		return

	marker.visible = has_marker_cell(cell)
	if not marker.visible:
		return

	var scaled_local := tilemap.map_to_local(cell) * tilemap.scale
	marker.position = tilemap.position + scaled_local


func _has_supported_player_cell(cell: Vector2i) -> bool:
	return _has_supported_cell(cell, player_solid_rects, player_platform_rects)


func _has_supported_shadow_cell(cell: Vector2i) -> bool:
	return _has_supported_cell(cell, shadow_solid_rects, shadow_platform_rects)


func _has_supported_cell(cell: Vector2i, solid_rects: Array[Rect2i], platform_rects: Array[Rect2i]) -> bool:
	if not has_marker_cell(cell):
		return false

	return _is_empty_cell(cell, solid_rects, platform_rects) and _is_filled_cell(cell + Vector2i.DOWN, solid_rects, platform_rects)


func _is_empty_cell(cell: Vector2i, solid_rects: Array[Rect2i], platform_rects: Array[Rect2i]) -> bool:
	return not _is_filled_cell(cell, solid_rects, platform_rects)


func _is_filled_cell(cell: Vector2i, solid_rects: Array[Rect2i], platform_rects: Array[Rect2i]) -> bool:
	return _rects_contain_cell(solid_rects, cell) or _rects_contain_cell(platform_rects, cell)


func _rects_contain_cell(rects: Array[Rect2i], cell: Vector2i) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false


func _collect_filled_cells(rects: Array[Rect2i], offset: Vector2i) -> Dictionary:
	var filled := {}
	for rect in rects:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				filled[Vector2i(x, y) + offset] = true
	return filled


func _collect_surface_cells(filled: Dictionary) -> Array[Vector2i]:
	var surface_cells: Array[Vector2i] = []
	for cell_variant in filled.keys():
		var cell := cell_variant as Vector2i
		if not filled.has(cell + Vector2i.UP):
			surface_cells.append(cell + Vector2i.UP)
	surface_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	return surface_cells


func _collect_reserved_cells(offset: Vector2i) -> Dictionary:
	var reserved := {}
	for marker_cell in [
		entry_cell,
		exit_cell,
		player_spawn_cell,
		shadow_spawn_cell,
		enemy_spawn_cell,
		key_spawn_cell,
		door_spawn_cell,
		shadow_area_spawn_cell,
	]:
		if not has_marker_cell(marker_cell):
			continue
		reserved[marker_cell + offset] = true
	return reserved


func _pick_story_surface(surface_cells: Array[Vector2i], filled: Dictionary, reserved: Dictionary, min_flat_run: int, salt: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for surface_cell in surface_cells:
		if _is_reserved_surface(surface_cell, reserved):
			continue
		if surface_cell.y < 6:
			continue
		if not _has_flat_run(filled, surface_cell, int(floor(min_flat_run * 0.5))):
			continue
		candidates.append(surface_cell)

	if candidates.is_empty():
		return INVALID_CELL

	var index := _positive_mod(_hash_ints([_chunk_hash_seed(), salt, width_in_cells, candidates.size()]), candidates.size())
	return candidates[index]


func _paint_story_prop(tilemap: TileMap, top_left: Vector2i, size: Vector2i, atlas: Vector2i) -> void:
	if top_left.y < 0:
		return
	if not _can_place_prop(tilemap, BACKGROUND_TILE_LAYER, top_left, size):
		return
	tilemap.set_cell(BACKGROUND_TILE_LAYER, top_left, DECOR_SOURCE_ID, atlas)


func _is_reserved_surface(surface_cell: Vector2i, reserved: Dictionary) -> bool:
	for reserved_cell_variant in reserved.keys():
		var reserved_cell := reserved_cell_variant as Vector2i
		if absi(reserved_cell.x - surface_cell.x) <= 2 and absi(reserved_cell.y - surface_cell.y) <= 2:
			return true
	return false


func _has_flat_run(filled: Dictionary, surface_cell: Vector2i, half_width: int) -> bool:
	var floor_y := surface_cell.y + 1
	for x in range(surface_cell.x - half_width, surface_cell.x + half_width + 1):
		var floor_cell := Vector2i(x, floor_y)
		if not filled.has(floor_cell) or filled.has(floor_cell + Vector2i.UP):
			return false
	return true


func _get_solid_atlas_for_cell(cell: Vector2i, filled: Dictionary, shadow_style: bool) -> Vector2i:
	if shadow_style:
		return SHADOW_SOLID_ATLAS

	var has_up := filled.has(cell + Vector2i.UP)
	var has_left := filled.has(cell + Vector2i.LEFT)
	var has_right := filled.has(cell + Vector2i.RIGHT)
	var has_down := filled.has(cell + Vector2i.DOWN)

	if not has_up:
		if not has_left and not has_right:
			return SURFACE_SINGLE_ATLAS
		if not has_left:
			return SURFACE_LEFT_ATLAS
		if not has_right:
			return SURFACE_RIGHT_ATLAS
		return _get_surface_center_atlas(cell)

	return _get_fill_atlas(cell, filled)


func _get_surface_center_atlas(cell: Vector2i) -> Vector2i:
	var band: int = _positive_mod(int(floor(float(cell.x + _chunk_hash_seed()) / 7.0)), 5)
	return SURFACE_CENTER_ACCENT_ATLAS if band == 0 else SURFACE_CENTER_ATLAS


func _get_fill_atlas(cell: Vector2i, filled: Dictionary) -> Vector2i:
	var depth := _get_fill_depth(cell, filled)
	if depth <= 1:
		return SHALLOW_FILL_ATLAS
	var patch_seed := _positive_mod(cell.x + int(floor(float(_chunk_hash_seed()) / 13.0)), 16)
	if depth == 2:
		return FILL_ACCENT_ATLAS if patch_seed >= 10 and patch_seed <= 13 else DEEP_FILL_PRIMARY_ATLAS
	if depth == 3:
		if patch_seed >= 10 and patch_seed <= 13:
			return DEEP_FILL_SECONDARY_ATLAS
		if patch_seed >= 4 and patch_seed <= 7:
			return FILL_ACCENT_ATLAS
	return DEEP_FILL_PRIMARY_ATLAS


func _get_fill_depth(cell: Vector2i, filled: Dictionary) -> int:
	var depth := 0
	var probe := cell
	while filled.has(probe + Vector2i.UP):
		depth += 1
		probe += Vector2i.UP
	return depth


func _pick_atlas(options: Array, cell: Vector2i, salt: int) -> Vector2i:
	var index: int = _positive_mod(_hash_ints([cell.x, cell.y, salt, _chunk_hash_seed()]), options.size())
	var atlas: Vector2i = options[index]
	return atlas


func _roll(cell: Vector2i, salt: int, threshold: float) -> bool:
	var bucket := _positive_mod(_hash_ints([cell.x, cell.y, salt, _chunk_hash_seed()]), 1000)
	return float(bucket) / 1000.0 < threshold


func _chunk_hash_seed() -> int:
	var value := 17
	var source: String = chunk_id if not chunk_id.is_empty() else name
	for i in source.length():
		value = int((value * 31) + source.unicode_at(i))
	return value


func _hash_ints(values: Array) -> int:
	var value := 23
	for item in values:
		value = int((value * 37) + int(item))
	return value


func _positive_mod(value: int, modulus: int) -> int:
	if modulus <= 0:
		return 0
	var result := value % modulus
	return result if result >= 0 else result + modulus


func _get_prop_size(atlas: Vector2i) -> Vector2i:
	if atlas == LARGE_TREE_ATLAS:
		return LARGE_TREE_SIZE
	if atlas == SMALL_TREE_ATLAS:
		return SMALL_TREE_SIZE
	if atlas == SHRUB_A_ATLAS or atlas == SHRUB_B_ATLAS:
		return SHRUB_SIZE
	if atlas == ROCK_A_ATLAS or atlas == ROCK_B_ATLAS:
		return ROCK_SIZE
	if atlas == GRASS_STRIP_ATLAS:
		return GRASS_STRIP_SIZE
	return Vector2i.ONE


func _get_surface_height_count(rects: Array[Rect2i]) -> int:
	var heights := {}
	for rect in rects:
		heights[rect.position.y - 1] = true
	return heights.size()


func _get_max_ground_gap(rects: Array[Rect2i]) -> int:
	if rects.size() < 2:
		return 0

	var sorted_rects: Array[Rect2i] = []
	for rect in rects:
		sorted_rects.append(rect)

	sorted_rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		if a.position.x == b.position.x:
			return a.position.y < b.position.y
		return a.position.x < b.position.x
	)

	var max_gap := 0
	for i in range(sorted_rects.size() - 1):
		var current_rect := sorted_rects[i]
		var next_rect := sorted_rects[i + 1]
		var current_end_x := current_rect.position.x + current_rect.size.x
		var gap := next_rect.position.x - current_end_x
		if gap > max_gap:
			max_gap = gap

	return maxi(max_gap, 0)


func _is_tree_atlas(atlas: Vector2i) -> bool:
	return atlas == SMALL_TREE_ATLAS or atlas == LARGE_TREE_ATLAS


func _can_place_tree(tilemap: TileMap, top_left: Vector2i, size: Vector2i) -> bool:
	var target_rect := Rect2i(top_left, size)
	for used_cell in tilemap.get_used_cells(PLAYER_TILE_LAYER):
		var atlas := tilemap.get_cell_atlas_coords(PLAYER_TILE_LAYER, used_cell)
		if not _is_tree_atlas(atlas):
			continue
		var existing_size := _get_prop_size(atlas)
		if Rect2i(used_cell, existing_size).intersects(target_rect):
			return false
	return true


func _can_place_prop(tilemap: TileMap, layer: int, top_left: Vector2i, size: Vector2i) -> bool:
	var target_rect := Rect2i(top_left, size)
	for used_cell in tilemap.get_used_cells(layer):
		var atlas := tilemap.get_cell_atlas_coords(layer, used_cell)
		var existing_size := _get_prop_size(atlas)
		if Rect2i(used_cell, existing_size).intersects(target_rect):
			return false
	return true


func _surface_range_is_free(x: int, occupied_ranges: Array[Vector2i]) -> bool:
	for occupied_range in occupied_ranges:
		if x >= occupied_range.x and x <= occupied_range.y:
			return false
	return true


func _describe_chunk() -> String:
	return chunk_id if not chunk_id.is_empty() else name

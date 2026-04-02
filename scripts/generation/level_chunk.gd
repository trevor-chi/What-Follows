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
const SHRUB_A_ATLAS := Vector2i(7, 5)
const SHRUB_B_ATLAS := Vector2i(7, 6)
const ROCK_A_ATLAS := Vector2i(3, 3)
const ROCK_B_ATLAS := Vector2i(3, 4)
const GRASS_STRIP_ATLAS := Vector2i(4, 8)
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

@export var paint_default_backdrop := true
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
		_paint_rects(player_tilemap, PLAYER_TILE_LAYER, player_solid_rects, PLAYER_SOLID_ATLAS)
		_paint_rects(player_tilemap, PLAYER_TILE_LAYER, player_platform_rects, PLAYER_PLATFORM_ATLAS)
		_paint_decorations(player_tilemap, Vector2i.ZERO)

	var shadow_tilemap := get_node_or_null("TileMapShadowChunk") as TileMap
	if shadow_tilemap:
		shadow_tilemap.clear()
		_paint_backdrop(shadow_tilemap, Vector2i.ZERO)
		_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, shadow_solid_rects, SHADOW_SOLID_ATLAS)
		_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, shadow_platform_rects, SHADOW_PLATFORM_ATLAS)

	_sync_marker_positions()


func stamp_into(player_tilemap: TileMap, shadow_tilemap: TileMap, offset: Vector2i) -> void:
	_paint_backdrop(player_tilemap, offset)
	_paint_rects(player_tilemap, PLAYER_TILE_LAYER, _offset_rects(player_solid_rects, offset), PLAYER_SOLID_ATLAS)
	_paint_rects(player_tilemap, PLAYER_TILE_LAYER, _offset_rects(player_platform_rects, offset), PLAYER_PLATFORM_ATLAS)
	_paint_decorations(player_tilemap, offset)
	_paint_backdrop(shadow_tilemap, offset)
	_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, _offset_rects(shadow_solid_rects, offset), SHADOW_SOLID_ATLAS)
	_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, _offset_rects(shadow_platform_rects, offset), SHADOW_PLATFORM_ATLAS)


func has_marker_cell(cell: Vector2i) -> bool:
	return cell != INVALID_CELL


func get_world_position_in(tilemap: TileMap, cell: Vector2i, offset: Vector2i = Vector2i.ZERO) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell + offset))


func get_exit_height_delta() -> int:
	return exit_cell.y - entry_cell.y


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


func _paint_backdrop(tilemap: TileMap, offset: Vector2i) -> void:
	if not paint_default_backdrop:
		return

	for x in range(0, width_in_cells, BACKDROP_REPEAT_WIDTH):
		for segment in BACKDROP_SEGMENTS:
			var cell := (segment["cell"] as Vector2i) + Vector2i(x + offset.x, 0)
			var atlas := segment["atlas"] as Vector2i
			tilemap.set_cell(BACKGROUND_TILE_LAYER, cell, BACKGROUND_SOURCE_ID, atlas)


func _paint_decorations(tilemap: TileMap, offset: Vector2i) -> void:
	_paint_cells(tilemap, BACKGROUND_TILE_LAYER, small_tree_cells, SMALL_TREE_ATLAS, offset)
	_paint_cells(tilemap, BACKGROUND_TILE_LAYER, large_tree_cells, LARGE_TREE_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, shrub_a_cells, SHRUB_A_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, shrub_b_cells, SHRUB_B_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, rock_a_cells, ROCK_A_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, rock_b_cells, ROCK_B_ATLAS, offset)
	_paint_cells(tilemap, FOREGROUND_TILE_LAYER, grass_strip_cells, GRASS_STRIP_ATLAS, offset)


func _paint_cells(tilemap: TileMap, layer: int, cells: Array[Vector2i], atlas_coords: Vector2i, offset: Vector2i) -> void:
	for cell in cells:
		tilemap.set_cell(layer, cell + offset, DECOR_SOURCE_ID, atlas_coords)


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


func _describe_chunk() -> String:
	return chunk_id if not chunk_id.is_empty() else name

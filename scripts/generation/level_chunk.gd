@tool
extends Node2D
class_name LevelChunk

const INVALID_CELL := Vector2i(-1, -1)
const PLAYER_TILE_LAYER := 1
const SHADOW_TILE_LAYER := 1
const PLAYER_SOLID_ATLAS := Vector2i(0, 9)
const PLAYER_PLATFORM_ATLAS := Vector2i(5, 4)
const SHADOW_SOLID_ATLAS := Vector2i(0, 9)
const SHADOW_PLATFORM_ATLAS := Vector2i(5, 4)

@export var chunk_id := ""
@export_enum("start", "path", "combat", "reward", "exit") var category := "path"
@export_range(1, 10, 1) var difficulty := 1
@export_range(4, 128, 1) var width_in_cells := 20

@export var player_solid_rects: Array[Rect2i] = []
@export var player_platform_rects: Array[Rect2i] = []
@export var shadow_solid_rects: Array[Rect2i] = []
@export var shadow_platform_rects: Array[Rect2i] = []

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
		_paint_rects(player_tilemap, PLAYER_TILE_LAYER, player_solid_rects, PLAYER_SOLID_ATLAS)
		_paint_rects(player_tilemap, PLAYER_TILE_LAYER, player_platform_rects, PLAYER_PLATFORM_ATLAS)

	var shadow_tilemap := get_node_or_null("TileMapShadowChunk") as TileMap
	if shadow_tilemap:
		shadow_tilemap.clear()
		_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, shadow_solid_rects, SHADOW_SOLID_ATLAS)
		_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, shadow_platform_rects, SHADOW_PLATFORM_ATLAS)

	_sync_marker_positions()


func stamp_into(player_tilemap: TileMap, shadow_tilemap: TileMap, offset: Vector2i) -> void:
	_paint_rects(player_tilemap, PLAYER_TILE_LAYER, _offset_rects(player_solid_rects, offset), PLAYER_SOLID_ATLAS)
	_paint_rects(player_tilemap, PLAYER_TILE_LAYER, _offset_rects(player_platform_rects, offset), PLAYER_PLATFORM_ATLAS)
	_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, _offset_rects(shadow_solid_rects, offset), SHADOW_SOLID_ATLAS)
	_paint_rects(shadow_tilemap, SHADOW_TILE_LAYER, _offset_rects(shadow_platform_rects, offset), SHADOW_PLATFORM_ATLAS)


func has_marker_cell(cell: Vector2i) -> bool:
	return cell != INVALID_CELL


func get_world_position_in(tilemap: TileMap, cell: Vector2i, offset: Vector2i = Vector2i.ZERO) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell + offset))


func _paint_rects(tilemap: TileMap, layer: int, rects: Array[Rect2i], atlas_coords: Vector2i) -> void:
	for rect in rects:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				tilemap.set_cell(layer, Vector2i(x, y), 0, atlas_coords)


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

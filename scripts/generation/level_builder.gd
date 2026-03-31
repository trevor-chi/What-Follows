extends RefCounted
class_name LevelBuilder

func build_level(template_scene: PackedScene, chunk_scenes: Array[PackedScene], save_path: String) -> Error:
	if template_scene == null:
		return ERR_INVALID_PARAMETER
	if chunk_scenes.is_empty():
		return ERR_INVALID_PARAMETER

	var level_root := template_scene.instantiate()
	if level_root == null:
		return ERR_CANT_CREATE

	var player_tilemap := level_root.get_node_or_null("TileMapPlayer") as TileMap
	var shadow_tilemap := level_root.get_node_or_null("TileMapShadow") as TileMap
	if player_tilemap == null or shadow_tilemap == null:
		level_root.free()
		return ERR_DOES_NOT_EXIST

	player_tilemap.clear()
	shadow_tilemap.clear()

	var player_spawn := Vector2.ZERO
	var shadow_spawn := Vector2.ZERO
	var enemy_spawn := Vector2.ZERO
	var key_spawn := Vector2.ZERO
	var door_spawn := Vector2.ZERO
	var shadow_area_spawn := Vector2.ZERO

	var has_player_spawn := false
	var has_shadow_spawn := false
	var has_enemy_spawn := false
	var has_key_spawn := false
	var has_door_spawn := false
	var has_shadow_area_spawn := false

	var cursor := Vector2i.ZERO
	for chunk_scene in chunk_scenes:
		if chunk_scene == null:
			continue

		var chunk := chunk_scene.instantiate() as LevelChunk
		if chunk == null:
			continue

		chunk.prepare_chunk()
		chunk.stamp_into(player_tilemap, shadow_tilemap, cursor)

		if not has_player_spawn and chunk.has_marker_cell(chunk.player_spawn_cell):
			player_spawn = chunk.get_world_position_in(player_tilemap, chunk.player_spawn_cell, cursor)
			has_player_spawn = true
		if not has_shadow_spawn and chunk.has_marker_cell(chunk.shadow_spawn_cell):
			shadow_spawn = chunk.get_world_position_in(shadow_tilemap, chunk.shadow_spawn_cell, cursor)
			has_shadow_spawn = true
		if not has_enemy_spawn and chunk.has_marker_cell(chunk.enemy_spawn_cell):
			enemy_spawn = chunk.get_world_position_in(player_tilemap, chunk.enemy_spawn_cell, cursor)
			has_enemy_spawn = true
		if not has_key_spawn and chunk.has_marker_cell(chunk.key_spawn_cell):
			key_spawn = chunk.get_world_position_in(player_tilemap, chunk.key_spawn_cell, cursor)
			has_key_spawn = true
		if not has_door_spawn and chunk.has_marker_cell(chunk.door_spawn_cell):
			door_spawn = chunk.get_world_position_in(player_tilemap, chunk.door_spawn_cell, cursor)
			has_door_spawn = true
		if not has_shadow_area_spawn and chunk.has_marker_cell(chunk.shadow_area_spawn_cell):
			shadow_area_spawn = chunk.get_world_position_in(player_tilemap, chunk.shadow_area_spawn_cell, cursor)
			has_shadow_area_spawn = true

		cursor.x += max(chunk.width_in_cells, 1)
		chunk.free()

	_set_node_position(level_root, "Player", player_spawn, has_player_spawn)
	_set_node_position(level_root, "Shadow", shadow_spawn if has_shadow_spawn else player_spawn, has_shadow_spawn or has_player_spawn)
	_set_node_position(level_root, "Enemy", enemy_spawn, has_enemy_spawn)
	_set_node_position(level_root, "Key", key_spawn, has_key_spawn)
	_set_door_and_blackness_position(level_root, door_spawn, has_door_spawn)
	_set_node_position(level_root, "ShadowArea", shadow_area_spawn, has_shadow_area_spawn)

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


func _set_node_position(level_root: Node, node_name: String, position: Vector2, should_apply: bool) -> void:
	if not should_apply:
		return

	var node := level_root.get_node_or_null(node_name) as Node2D
	if node:
		node.position = position


func _set_door_and_blackness_position(level_root: Node, door_position: Vector2, should_apply: bool) -> void:
	if not should_apply:
		return

	var door := level_root.get_node_or_null("Door") as Node2D
	if door == null:
		return

	var delta := door_position - door.position
	door.position = door_position

	var door_blackness := level_root.get_node_or_null("DoorBlackness") as Node2D
	if door_blackness:
		door_blackness.position += delta

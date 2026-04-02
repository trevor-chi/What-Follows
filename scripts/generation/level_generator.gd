@tool
extends Node
class_name LevelGenerator

@export var template_scene: PackedScene
@export var output_scene_path := "res://generated_levels/generated_level.tscn"
@export var seed := 1
@export_range(0, 8, 1) var extra_path_chunk_count := 1
@export_range(1, 64, 1) var max_generation_attempts := 24
@export_range(4, 20, 1) var min_route_floor_y := 5
@export_range(4, 20, 1) var max_route_floor_y := 12
@export var avoid_immediate_repeats := true

@export var start_chunks: Array[PackedScene] = []
@export var path_chunks: Array[PackedScene] = []
@export var combat_chunks: Array[PackedScene] = []
@export var reward_chunks: Array[PackedScene] = []
@export var exit_chunks: Array[PackedScene] = []

var _build_now := false

@export var build_now := false:
	get:
		return _build_now
	set(value):
		_build_now = value
		if not value:
			return

		_build_now = false
		if Engine.is_editor_hint():
			var error := build_level_scene()
			if error != OK:
				push_error("Level generation failed with error code %s." % error)


func build_level_scene() -> Error:
	if template_scene == null:
		push_error("Assign a template scene before building generated levels.")
		return ERR_INVALID_PARAMETER

	var builder := LevelBuilder.new()
	for attempt in range(max_generation_attempts):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + (attempt * 104729)

		var sequence := _plan_sequence(rng)
		if sequence.is_empty():
			continue

		var error := builder.build_level(template_scene, sequence, output_scene_path)
		if error == OK:
			print("Generated level saved to %s on attempt %d" % [output_scene_path, attempt + 1])
			return OK

	push_error("Unable to build a playable level after %d attempts." % max_generation_attempts)
	return ERR_CANT_CREATE


func _plan_sequence(rng: RandomNumberGenerator) -> Array[PackedScene]:
	var sequence: Array[PackedScene] = []
	var current_floor_y := 0
	var last_chunk_id := ""
	var is_first_chunk := true

	var start_pick := _pick_chunk_for_phase(start_chunks, "start", 1, current_floor_y, last_chunk_id, rng, is_first_chunk)
	if start_pick.is_empty():
		return []
	sequence.append(start_pick["scene"])
	current_floor_y = int(start_pick["exit_floor_y"])
	last_chunk_id = String(start_pick["chunk_id"])
	is_first_chunk = false

	for i in range(extra_path_chunk_count):
		var target_difficulty := mini(1 + i, 3)
		var path_pick := _pick_chunk_for_phase(path_chunks, "path", target_difficulty, current_floor_y, last_chunk_id, rng, false)
		if path_pick.is_empty():
			return []
		sequence.append(path_pick["scene"])
		current_floor_y = int(path_pick["exit_floor_y"])
		last_chunk_id = String(path_pick["chunk_id"])

	var combat_pick := _pick_chunk_for_phase(combat_chunks, "combat", 3, current_floor_y, last_chunk_id, rng, false)
	if combat_pick.is_empty():
		return []
	sequence.append(combat_pick["scene"])
	current_floor_y = int(combat_pick["exit_floor_y"])
	last_chunk_id = String(combat_pick["chunk_id"])

	var reward_pick := _pick_chunk_for_phase(reward_chunks, "reward", 3, current_floor_y, last_chunk_id, rng, false)
	if reward_pick.is_empty():
		return []
	sequence.append(reward_pick["scene"])
	current_floor_y = int(reward_pick["exit_floor_y"])
	last_chunk_id = String(reward_pick["chunk_id"])

	var exit_pick := _pick_chunk_for_phase(exit_chunks, "exit", 4, current_floor_y, last_chunk_id, rng, false)
	if exit_pick.is_empty():
		return []
	sequence.append(exit_pick["scene"])

	return sequence


func _pick_chunk_for_phase(pool: Array[PackedScene], expected_category: String, target_difficulty: int, current_floor_y: int, last_chunk_id: String, rng: RandomNumberGenerator, is_first_chunk: bool) -> Dictionary:
	if pool.is_empty():
		push_error("The %s chunk pool is empty." % expected_category)
		return {}

	var candidates: Array[Dictionary] = []
	for scene in pool:
		if scene == null:
			continue

		var chunk := scene.instantiate() as LevelChunk
		if chunk == null:
			continue

		var candidate := _evaluate_candidate(scene, chunk, expected_category, target_difficulty, current_floor_y, last_chunk_id, is_first_chunk)
		chunk.free()
		if candidate.is_empty():
			continue
		candidates.append(candidate)

	if candidates.is_empty():
		return {}

	var total_weight := 0
	for candidate in candidates:
		total_weight += int(candidate["weight"])

	var roll := rng.randi_range(1, max(total_weight, 1))
	for candidate in candidates:
		roll -= int(candidate["weight"])
		if roll <= 0:
			return candidate

	return candidates[0]


func _evaluate_candidate(scene: PackedScene, chunk: LevelChunk, expected_category: String, target_difficulty: int, current_floor_y: int, last_chunk_id: String, is_first_chunk: bool) -> Dictionary:
	if chunk.category != expected_category:
		return {}
	if avoid_immediate_repeats and not is_first_chunk and chunk.chunk_id == last_chunk_id:
		return {}

	var errors := chunk.get_validation_errors()
	if not errors.is_empty():
		return {}

	if expected_category == "combat" and not chunk.has_marker_cell(chunk.enemy_spawn_cell):
		return {}
	if expected_category == "reward" and not chunk.has_marker_cell(chunk.key_spawn_cell):
		return {}
	if expected_category == "exit" and not chunk.has_marker_cell(chunk.door_spawn_cell):
		return {}
	if expected_category == "start":
		if not chunk.has_marker_cell(chunk.player_spawn_cell) or not chunk.has_marker_cell(chunk.shadow_spawn_cell):
			return {}

	var exit_floor_y: int = chunk.exit_cell.y
	if is_first_chunk:
		if exit_floor_y < min_route_floor_y or exit_floor_y > max_route_floor_y:
			return {}
	else:
		exit_floor_y = current_floor_y + chunk.get_exit_height_delta()
		if exit_floor_y < min_route_floor_y or exit_floor_y > max_route_floor_y:
			return {}

	var difficulty_gap: int = absi(chunk.difficulty - target_difficulty)
	var difficulty_weight: int = maxi(1, 6 - (difficulty_gap * 2))
	var route_center: int = int((min_route_floor_y + max_route_floor_y) * 0.5)
	var route_weight: int = maxi(1, 6 - absi(exit_floor_y - route_center))
	var total_weight: int = maxi(1, chunk.selection_weight * difficulty_weight * route_weight)

	return {
		"scene": scene,
		"chunk_id": chunk.chunk_id,
		"exit_floor_y": exit_floor_y,
		"weight": total_weight,
	}

@tool
extends Node
class_name LevelGenerator

@export var template_scene: PackedScene
@export var output_scene_path := "res://generated_levels/generated_level.tscn"
@export var seed := 1
@export_range(0, 8, 1) var extra_path_chunk_count := 2
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

	var start_pick := _pick_chunk_for_phase_with_fallbacks(
		start_chunks,
		"start",
		1,
		current_floor_y,
		last_chunk_id,
		rng,
		is_first_chunk,
		[
			{"prefer_vertical": true},
			{},
		]
	)
	if start_pick.is_empty():
		return []
	sequence.append(start_pick["scene"])
	current_floor_y = int(start_pick["exit_floor_y"])
	last_chunk_id = String(start_pick["chunk_id"])
	is_first_chunk = false

	var path_specs := _build_path_specs()
	for i in range(path_specs.size()):
		var path_spec: Dictionary = path_specs[i]
		var target_difficulty := int(path_spec["target_difficulty"])
		var requirements: Array[Dictionary] = path_spec["requirements"]
		var path_pick := _pick_chunk_for_phase_with_fallbacks(
			path_chunks,
			"path",
			target_difficulty,
			current_floor_y,
			last_chunk_id,
			rng,
			false,
			requirements
		)
		if path_pick.is_empty():
			return []
		sequence.append(path_pick["scene"])
		current_floor_y = int(path_pick["exit_floor_y"])
		last_chunk_id = String(path_pick["chunk_id"])

	var combat_pick := _pick_chunk_for_phase_with_fallbacks(
		combat_chunks,
		"combat",
		3,
		current_floor_y,
		last_chunk_id,
		rng,
		false,
		[
			{"require_movement": true, "prefer_vertical": true},
			{"prefer_vertical": true},
			{},
		]
	)
	if combat_pick.is_empty():
		return []
	sequence.append(combat_pick["scene"])
	current_floor_y = int(combat_pick["exit_floor_y"])
	last_chunk_id = String(combat_pick["chunk_id"])

	var reward_pick := _pick_chunk_for_phase_with_fallbacks(
		reward_chunks,
		"reward",
		4,
		current_floor_y,
		last_chunk_id,
		rng,
		false,
		[
			{"require_movement": true, "prefer_vertical": true, "prefer_gap": true},
			{"require_movement": true, "prefer_vertical": true},
			{"prefer_gap": true},
			{},
		]
	)
	if reward_pick.is_empty():
		return []
	sequence.append(reward_pick["scene"])
	current_floor_y = int(reward_pick["exit_floor_y"])
	last_chunk_id = String(reward_pick["chunk_id"])

	var exit_pick := _pick_chunk_for_phase_with_fallbacks(
		exit_chunks,
		"exit",
		4,
		current_floor_y,
		last_chunk_id,
		rng,
		false,
		[
			{"require_movement": true, "prefer_vertical": true},
			{"prefer_vertical": true},
			{},
		]
	)
	if exit_pick.is_empty():
		return []
	sequence.append(exit_pick["scene"])

	return sequence


func _build_path_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var path_count := maxi(extra_path_chunk_count, 2)

	for i in range(path_count):
		var requirement_chain: Array[Dictionary] = []
		var target_difficulty := mini(2 + i, 4)
		if i == 0:
			requirement_chain = [
				{"require_movement": true, "prefer_gap": true, "prefer_vertical": true},
				{"require_movement": true, "prefer_gap": true},
				{"require_movement": true},
			]
		elif i == 1:
			requirement_chain = [
				{"require_movement": true, "require_vertical": true, "prefer_gap": true},
				{"require_movement": true, "prefer_vertical": true},
				{"require_movement": true},
			]
		else:
			var prefer_gap := i % 2 == 0
			var prefer_vertical := not prefer_gap
			requirement_chain = [
				{"require_movement": true, "prefer_gap": prefer_gap, "prefer_vertical": prefer_vertical},
				{"require_movement": true, "prefer_vertical": prefer_vertical},
				{"require_movement": true},
			]

		specs.append({
			"target_difficulty": target_difficulty,
			"requirements": requirement_chain,
		})

	return specs


func _pick_chunk_for_phase_with_fallbacks(pool: Array[PackedScene], expected_category: String, target_difficulty: int, current_floor_y: int, last_chunk_id: String, rng: RandomNumberGenerator, is_first_chunk: bool, requirement_chain: Array[Dictionary]) -> Dictionary:
	for requirements in requirement_chain:
		var pick := _pick_chunk_for_phase(pool, expected_category, target_difficulty, current_floor_y, last_chunk_id, rng, is_first_chunk, requirements)
		if not pick.is_empty():
			return pick
	return {}


func _pick_chunk_for_phase(pool: Array[PackedScene], expected_category: String, target_difficulty: int, current_floor_y: int, last_chunk_id: String, rng: RandomNumberGenerator, is_first_chunk: bool, requirements: Dictionary = {}) -> Dictionary:
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

		var candidate := _evaluate_candidate(scene, chunk, expected_category, target_difficulty, current_floor_y, last_chunk_id, is_first_chunk, requirements)
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


func _evaluate_candidate(scene: PackedScene, chunk: LevelChunk, expected_category: String, target_difficulty: int, current_floor_y: int, last_chunk_id: String, is_first_chunk: bool, requirements: Dictionary) -> Dictionary:
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

	if bool(requirements.get("require_movement", false)) and chunk.get_challenge_score() < 4:
		return {}
	if bool(requirements.get("require_gap", false)) and not chunk.has_gap_navigation():
		return {}
	if bool(requirements.get("require_vertical", false)) and not chunk.has_vertical_navigation():
		return {}
	if bool(requirements.get("require_platform", false)) and not chunk.has_platform_navigation():
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
	var challenge_weight := maxi(1, chunk.get_challenge_score())
	if bool(requirements.get("prefer_gap", false)) and chunk.has_gap_navigation():
		challenge_weight += 5
	if bool(requirements.get("prefer_vertical", false)) and chunk.has_vertical_navigation():
		challenge_weight += 5
	if bool(requirements.get("prefer_platform", false)) and chunk.has_platform_navigation():
		challenge_weight += 4
	if expected_category == "path":
		if not chunk.has_gap_navigation() and not chunk.has_vertical_navigation():
			challenge_weight = maxi(1, challenge_weight - 3)
		if chunk.chunk_id.contains("flat"):
			challenge_weight = maxi(1, challenge_weight - 2)
	if expected_category == "combat" and chunk.has_vertical_navigation():
		challenge_weight += 2
	if expected_category == "reward" and (chunk.has_gap_navigation() or chunk.has_vertical_navigation()):
		challenge_weight += 2
	if expected_category == "exit" and chunk.has_vertical_navigation():
		challenge_weight += 3
	var total_weight: int = maxi(1, chunk.selection_weight * difficulty_weight * route_weight * challenge_weight)

	return {
		"scene": scene,
		"chunk_id": chunk.chunk_id,
		"exit_floor_y": exit_floor_y,
		"weight": total_weight,
	}

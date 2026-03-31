@tool
extends Node
class_name LevelGenerator

@export var template_scene: PackedScene
@export var output_scene_path := "res://generated_levels/generated_level.tscn"
@export var seed := 1
@export_range(0, 8, 1) var extra_path_chunk_count := 1

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

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var sequence: Array[PackedScene] = []
	if not _append_random_chunk(sequence, start_chunks, rng):
		return ERR_INVALID_PARAMETER

	for _i in range(extra_path_chunk_count):
		if path_chunks.is_empty():
			break
		_append_random_chunk(sequence, path_chunks, rng)

	if not _append_random_chunk(sequence, combat_chunks, rng):
		return ERR_INVALID_PARAMETER
	if not _append_random_chunk(sequence, reward_chunks, rng):
		return ERR_INVALID_PARAMETER
	if not _append_random_chunk(sequence, exit_chunks, rng):
		return ERR_INVALID_PARAMETER

	var builder := LevelBuilder.new()
	var error := builder.build_level(template_scene, sequence, output_scene_path)
	if error == OK:
		print("Generated level saved to %s" % output_scene_path)
	return error


func _append_random_chunk(target: Array[PackedScene], pool: Array[PackedScene], rng: RandomNumberGenerator) -> bool:
	if pool.is_empty():
		push_error("A required chunk pool is empty.")
		return false

	target.append(pool[rng.randi_range(0, pool.size() - 1)])
	return true

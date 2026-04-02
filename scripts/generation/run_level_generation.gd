extends SceneTree

func _init() -> void:
	var generator_scene := load("res://scenes/generation/LevelGenerator.tscn") as PackedScene
	if generator_scene == null:
		push_error("Could not load LevelGenerator scene.")
		quit(1)
		return

	var generator: Node = generator_scene.instantiate()
	if generator == null:
		push_error("Could not instantiate LevelGenerator scene.")
		quit(1)
		return

	root.add_child(generator)

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.size() >= 1 and user_args[0] != "":
		generator.set("seed", int(user_args[0]))
	if user_args.size() >= 2 and user_args[1] != "":
		generator.set("output_scene_path", user_args[1])

	var error: int = int(generator.call("build_level_scene"))
	if error != OK:
		push_error("Level generation failed with error code %s." % error)
		quit(int(error))
		return

	quit(0)

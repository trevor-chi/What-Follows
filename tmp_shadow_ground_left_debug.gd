extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main

	await process_frame
	await physics_frame

	var player := main.get_node("Player") as CharacterBody2D
	var shadow := main.get_node("Shadow") as CharacterBody2D
	var left_wall := main.get_node("LevelWalls/LeftWall") as StaticBody2D

	player.global_position = Vector2(left_wall.global_position.x + 140.0, 520.0)
	player.velocity = Vector2.ZERO
	shadow.global_position = player.global_position + Vector2(260.0, 0.0)
	shadow.velocity = Vector2.ZERO
	shadow.set("follow_delay", 20)
	if shadow.has_method("reset_queue"):
		shadow.reset_queue()

	Input.action_press("move_left")

	for i in range(70):
		await physics_frame
		if i % 5 == 0 or i >= 55:
			var queue = shadow.get("state_queue")
			var queued_dir = "n/a"
			if queue is Array and queue.size() > 0:
				var front = queue[0]
				if front is Dictionary and front.has("move_dir"):
					queued_dir = front["move_dir"]
			print(
				"frame=", i,
				" player_x=", snappedf(player.global_position.x, 0.01),
				" player_input=", player.get("move_input_dir"),
				" shadow_x=", snappedf(shadow.global_position.x, 0.01),
				" shadow_vx=", snappedf(shadow.velocity.x, 0.01),
				" shadow_floor=", shadow.is_on_floor(),
				" queued_dir=", queued_dir
			)

	Input.action_release("move_left")
	quit()

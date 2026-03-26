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

	var player := main.get_node("Player") as CharacterBody2D
	var shadow := main.get_node("Shadow") as CharacterBody2D

	player.global_position = Vector2(200.0, 200.0)
	shadow.global_position = Vector2(260.0, 200.0)
	player.velocity = Vector2.ZERO
	shadow.velocity = Vector2.ZERO

	for i in range(120):
		await physics_frame
		if i in [0, 20, 40, 60, 80, 100, 119]:
			print(
				"frame=", i,
				" player_y=", snappedf(player.global_position.y, 0.01),
				" player_floor=", player.is_on_floor(),
				" shadow_y=", snappedf(shadow.global_position.y, 0.01),
				" shadow_floor=", shadow.is_on_floor(),
				" shadow_mask=", shadow.collision_mask
			)

	quit()

extends Node2D
# Attach this to your main scene root

@export var player: CharacterBody2D
@export var shadow: CharacterBody2D

func _ready():
	if not player or not shadow:
		push_error("Player and Shadow must be assigned in the inspector.")

func _unhandled_input(event):
	if event.is_action_pressed("swap_sprites"):  # make sure InputMap has "swap" mapped to Space
		swap_positions()

func swap_positions():
	if not player or not shadow:
		return

	# --- Save current sprite transforms for perfect visual alignment ---
	var player_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var shadow_sprite = shadow.get_node("AnimatedSprite2D") as AnimatedSprite2D

	var player_transform = player_sprite.global_transform
	var shadow_transform = shadow_sprite.global_transform

	# --- Swap positions ---
	player.global_position = shadow_transform.origin - (player_sprite.position)
	shadow.global_position = player_transform.origin - (shadow_sprite.position)

	# --- Swap velocities ---
	var temp_vel = player.velocity
	player.velocity = shadow.velocity
	shadow.velocity = temp_vel

	# --- Reset shadow queue to prevent double jumps or replaying old motion ---
	if shadow.has_method("reset_queue"):
		shadow.reset_queue()

	# --- Force shadow to fall if the player was mid-air ---
	if not player.is_on_floor() and shadow.has_variable("force_fall"):
		shadow.force_fall = true

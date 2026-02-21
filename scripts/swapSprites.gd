extends Node2D

@export var player: CharacterBody2D
@export var shadow: CharacterBody2D

var _swap_requested := false

func _unhandled_input(event):
	if event.is_action_pressed("swap_sprites"):
		_swap_requested = true

func _physics_process(_delta):
	if _swap_requested:
		_swap_requested = false
		swap_positions()

func swap_positions():
	if not player or not shadow:
		return

	var p_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var s_sprite := shadow.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if not p_sprite or not s_sprite:
		return

	var p_sprite_pos := p_sprite.global_position
	var s_sprite_pos := s_sprite.global_position

	var p_vel := player.velocity
	var s_vel := shadow.velocity

	# Move bodies so rendered sprites land exactly on each other's old spot
	player.global_position += (s_sprite_pos - p_sprite_pos)
	shadow.global_position += (p_sprite_pos - s_sprite_pos)

	player.velocity = s_vel
	shadow.velocity = p_vel

	if shadow.has_method("reset_queue"):
		shadow.reset_queue()

# MainScene.gd
extends Node2D

@export var player: CharacterBody2D
@export var shadow: CharacterBody2D
@export var enemy: CharacterBody2D
@export var key: Node

var _swap_requested := false

func _ready() -> void:
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	if enemy and enemy.has_signal("defeated"):
		if not enemy.defeated.is_connected(_on_enemy_defeated):
			enemy.defeated.connect(_on_enemy_defeated)

	if key and key.has_method("set_available"):
		key.call("set_available", false)

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

	player.global_position += (s_sprite_pos - p_sprite_pos)
	shadow.global_position += (p_sprite_pos - s_sprite_pos)

	player.velocity = s_vel
	shadow.velocity = p_vel

	if shadow.has_method("reset_queue"):
		shadow.reset_queue()

func _on_enemy_defeated() -> void:
	if key and key.has_method("set_available"):
		key.call("set_available", true)

func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

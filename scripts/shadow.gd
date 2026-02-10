extends Node2D

@export var target: CharacterBody2D
@export var offset := Vector2(6, 8)

@onready var shadow_sprite := $AnimatedSprite2D

func _process(_delta):
	if not target:
		return

	global_position = target.global_position + offset
	
	var player_sprite = target.get_node("AnimatedSprite2D")
	shadow_sprite.animation = player_sprite.animation
	shadow_sprite.frame = player_sprite.frame
	shadow_sprite.flip_h = player_sprite.flip_h

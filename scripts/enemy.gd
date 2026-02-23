extends CharacterBody2D

@export var speed: float = 220.0
@export var stop_distance: float = 28.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D

var target_player: CharacterBody2D = null
var player_in_range: bool = false

func _ready() -> void:
	anim.play("Idle")
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)

func _physics_process(_delta: float) -> void:
	if player_in_range and is_instance_valid(target_player):
		var dx := target_player.global_position.x - global_position.x
		var abs_dx := absf(dx)

		if abs_dx > stop_distance:
			velocity.x = sign(dx) * speed
			velocity.y = 0.0
			anim.play("Run")
			anim.flip_h = velocity.x < 0.0
		else:
			velocity = Vector2.ZERO
			anim.play("Idle")
	else:
		velocity = Vector2.ZERO
		anim.play("Idle")

	move_and_slide()

func _on_detection_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		target_player = body as CharacterBody2D
		player_in_range = true

func _on_detection_body_exited(body: Node) -> void:
	if body == target_player:
		target_player = null
		player_in_range = false

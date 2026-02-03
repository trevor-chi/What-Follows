extends CharacterBody2D

@onready var anim := $AnimatedSprite2D

@export var speed := 400.0
@export var jumpVel := 600.0
@export var gravity := 1200.0

func _ready():
	anim.play("Idle")

func play_anim(name: String):
	if anim.animation != name:
		anim.play(name)

func _physics_process(delta):
	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jumpVel

	# horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	# animations
	if not is_on_floor():
		play_anim("Jump")
		anim.flip_h = direction < 0
	elif direction != 0:
		play_anim("Running")
		anim.flip_h = direction < 0
	else:
		play_anim("Idle")

	move_and_slide()

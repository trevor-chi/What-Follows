extends CharacterBody2D

@export var speed := 200.0

func _physics_process(_delta):
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	move_and_slide()
	
	if Input.is_action_pressed("move_left"):
		print("LEFT")
	
	if Input.is_action_pressed("move_right"):
		print("RIGHT")
	

extends CharacterBody2D

# --- Exports ---
@export var target: CharacterBody2D
@export var gravity: float = 1100.0
@export var speed: float = 400.0

# --- Node References ---
@onready var shadow_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Internal State ---
var facing_left: bool = false
var current_animation: String = ""  # Track current animation to prevent restarting

func _physics_process(delta):
	if not target:
		return

	# --- 1. Horizontal Movement ---
	var displacement = target.global_position - global_position
	var horizontal_velocity = displacement.x / delta
	horizontal_velocity = clamp(horizontal_velocity, -speed, speed)
	velocity.x = horizontal_velocity

	# --- 2. Vertical Movement ---
	if is_on_floor() and not target.is_on_floor() and target.velocity.y < 0:
		velocity.y = target.velocity.y * 1.05
	velocity.y += gravity * delta

	# --- 3. Move Physics ---
	move_and_slide()

	# --- 4. Determine Animation ---
	var new_animation: String
	if not is_on_floor():
		new_animation = "Jump"
	elif velocity.x != 0:
		new_animation = "Running"
	else:
		new_animation = "Idle"

	# Only switch animation if it changed
	if new_animation != current_animation:
		shadow_sprite.animation = new_animation
		shadow_sprite.play()
		current_animation = new_animation

	# --- 5. Flip Sprite ---
	if velocity.x != 0:
		facing_left = velocity.x < 0
	shadow_sprite.flip_h = facing_left

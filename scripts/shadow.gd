extends CharacterBody2D

# --- Exports ---
@export var target: CharacterBody2D
@export var gravity: float = 1100.0
@export var speed: float = 400.0
@export var jump_speed: float = 775.0      # matches player jump impulse
@export var follow_delay: int = 50          # frames of delay
@export var stop_threshold: float = 0.5     # horizontal tolerance for instant stop
@export var jump_velocity_threshold: float = -10.0  # min velocity to consider a real jump

# --- Node References ---
@onready var shadow_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Internal State ---
var facing_left: bool = false
var current_animation: String = ""
var state_queue: Array = []

func _ready():
	if target:
		global_position = target.global_position
		# Pre-fill queue
		for i in range(follow_delay):
			state_queue.append({
				"position": target.global_position,
				"velocity": target.velocity
			})

func _physics_process(delta):
	if not target:
		return

	# --- 1. Record Player State ---
	state_queue.append({
		"position": target.global_position,
		"velocity": target.velocity
	})

	# --- 2. Apply Delayed Movement ---
	if state_queue.size() > follow_delay:
		var delayed = state_queue.pop_front()
		var delayed_velocity: Vector2 = delayed.velocity

		# --- 2a. Horizontal Movement ---
		var dx = delayed.position.x - global_position.x
		if abs(dx) < stop_threshold:
			velocity.x = 0  # instant stop
		else:
			velocity.x = delayed_velocity.x

		# --- 2b. Vertical Movement ---
		# Jump mimic: only trigger if player is actually jumping (velocity threshold)
		if delayed_velocity.y < jump_velocity_threshold and is_on_floor():
			velocity.y = -jump_speed

		# Gravity is always applied
		velocity.y += gravity * delta

		# --- 2c. Move with collisions ---
		move_and_slide()

		# --- 3. Animations ---
		var new_animation: String
		if not is_on_floor():
			new_animation = "Jump"
		elif abs(velocity.x) > 0:
			new_animation = "Running"
		else:
			new_animation = "Idle"

		if new_animation != current_animation:
			shadow_sprite.animation = new_animation
			shadow_sprite.play()
			current_animation = new_animation

		# --- 4. Flip sprite ---
		if velocity.x != 0:
			facing_left = velocity.x < 0
		shadow_sprite.flip_h = facing_left

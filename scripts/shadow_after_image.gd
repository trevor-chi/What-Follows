extends CharacterBody2D

# --- Exports ---
@export var target: CharacterBody2D
@export var gravity: float = 1100.0
@export var speed: float = 400.0
@export var jump_speed: float = 775.0
@export var follow_delay: int = 50
@export var stop_threshold: float = 0.5
@export var jump_velocity_threshold: float = -10.0

@export var afterimage_scene: PackedScene
@export var afterimage_interval: float = 0.05
@export var afterimage_lifetime: float = 0.25
@export var afterimage_start_alpha: float = 0.5

# --- Node References ---
@onready var shadow_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Internal State ---
var facing_left: bool = false
var current_animation: String = ""
var state_queue: Array = []
var afterimage_timer: float = 0.0

func _ready():
	if target:
		global_position = target.global_position
		for i in range(follow_delay):
			state_queue.append({
				"position": target.global_position,
				"velocity": target.velocity
			})

func _physics_process(delta):
	if not target:
		return

	# --- Record Player State ---
	state_queue.append({
		"position": target.global_position,
		"velocity": target.velocity
	})

	if state_queue.size() > follow_delay:
		var delayed = state_queue.pop_front()
		var delayed_velocity: Vector2 = delayed.velocity

		# --- Horizontal ---
		var dx = delayed.position.x - global_position.x
		if abs(dx) < stop_threshold:
			velocity.x = 0
		else:
			velocity.x = delayed_velocity.x

		# --- Vertical ---
		if delayed_velocity.y < jump_velocity_threshold and is_on_floor():
			velocity.y = -jump_speed

		velocity.y += gravity * delta
		move_and_slide()

		# --- Animations ---
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

		# --- Flip ---
		if velocity.x != 0:
			facing_left = velocity.x < 0
		shadow_sprite.flip_h = facing_left

	# --- Spawn Motion Blur ---
	afterimage_timer += delta

	if afterimage_timer >= afterimage_interval \
	and velocity.length() > 0.1 \
	and afterimage_scene:

		afterimage_timer = 0.0
		spawn_afterimage()


func spawn_afterimage():
	var after_image = afterimage_scene.instantiate() as AnimatedSprite2D

	# Copy visual state
	after_image.global_position = global_position
	after_image.flip_h = shadow_sprite.flip_h
	after_image.animation = shadow_sprite.animation
	after_image.frame = shadow_sprite.frame
	after_image.scale = shadow_sprite.scale
	after_image.modulate = Color(0, 0, 0, afterimage_start_alpha)

	get_parent().add_child(after_image)

	# Smooth fade out using Tween
	var tween = create_tween()
	tween.tween_property(
		after_image,
		"modulate:a",
		0.0,
		afterimage_lifetime
	)

	tween.tween_callback(after_image.queue_free)

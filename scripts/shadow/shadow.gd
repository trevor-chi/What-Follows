extends CharacterBody2D

# --- Exports ---
@export var target: CharacterBody2D
@export var gravity: float = 1100.0
@export var speed: float = 400.0
@export var jump_speed: float = 775.0
@export var follow_delay: int = 50
@export var stop_threshold: float = 0.5

@export var afterimage_scene: PackedScene
@export var afterimage_interval: float = 0.05
@export var afterimage_lifetime: float = 0.25
@export var afterimage_start_alpha: float = 0.5

# --- Node Reference ---
@onready var shadow_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Internal State ---
var state_queue: Array = []
var current_animation: String = ""
var facing_left := false
var afterimage_timer := 0.0
var force_fall := false  # prevents jumping immediately after a mid-air swap

func _ready():
	if target:
		global_position = target.global_position
		# Pre-fill queue for smooth delay
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

		# --- Horizontal Movement ---
		var dx = delayed.position.x - global_position.x
		if abs(dx) < stop_threshold:
			velocity.x = 0
		else:
			velocity.x = delayed_velocity.x

		# --- Vertical Movement ---
		# Calculate relative vertical position
		var dy = delayed.position.y - global_position.y

		# Jump only if:
		# 1. Shadow is on floor
		# 2. Player is above shadow (moving upward relative to it)
		# 3. Not forced to fall from swap
		if is_on_floor() and not force_fall and dy < -0.1:
			velocity.y = -jump_speed

		# Apply gravity
		velocity.y += gravity * delta

		move_and_slide()

		# Reset force_fall once shadow lands
		if is_on_floor() and force_fall:
			force_fall = false

		# --- Animations ---
		var new_anim: String
		if not is_on_floor():
			new_anim = "Jump"
		elif abs(velocity.x) > 0:
			new_anim = "Running"
		else:
			new_anim = "Idle"

		if new_anim != current_animation:
			shadow_sprite.animation = new_anim
			shadow_sprite.play()
			current_animation = new_anim

		# --- Flip Sprite ---
		if velocity.x != 0:
			facing_left = velocity.x < 0
		shadow_sprite.flip_h = facing_left

	# --- 3. After-Images (Motion Blur) ---
	afterimage_timer += delta
	if afterimage_timer >= afterimage_interval and velocity.length() > 0.1 and afterimage_scene:
		afterimage_timer = 0.0
		spawn_afterimage()

# --- Spawn After-Image Safely ---
func spawn_afterimage():
	var after_image = afterimage_scene.instantiate()
	if not after_image:
		return

	get_tree().current_scene.add_child(after_image)

	# Match shadow's global transform
	after_image.global_transform = global_transform

	# Copy the child AnimatedSprite2D inside the after-image scene
	var sprite = after_image.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.animation = shadow_sprite.animation
		sprite.frame = shadow_sprite.frame
		sprite.flip_h = shadow_sprite.flip_h
		sprite.modulate = Color(0, 0, 0, afterimage_start_alpha)

		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, afterimage_lifetime)
		tween.tween_callback(after_image.queue_free)

# --- Reset queue (for swaps) ---
func reset_queue():
	state_queue.clear()
	for i in range(follow_delay):
		state_queue.append({
			"position": target.global_position,
			"velocity": target.velocity
		})

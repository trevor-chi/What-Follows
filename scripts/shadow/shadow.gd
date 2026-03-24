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
var force_fall := false


func _ready() -> void:
	floor_snap_length = 10.0

	reset_queue()


func _physics_process(delta: float) -> void:
	if not target:
		velocity.y += gravity * delta
		move_and_slide()
		return

	_record_target_state(delta)

	if state_queue.size() > follow_delay:
		var delayed: Dictionary = state_queue.pop_front()
		_apply_delayed_state(delayed, delta)
	else:
		velocity.y += gravity * delta
		move_and_slide()

	afterimage_timer += delta
	if afterimage_timer >= afterimage_interval and velocity.length() > 0.1 and afterimage_scene:
		afterimage_timer = 0.0
		spawn_afterimage()


func _record_target_state(_delta: float) -> void:
	var target_sprite := target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var attack_anim := ""
	if target_sprite and target_sprite.animation.begins_with("Attack_"):
		attack_anim = target_sprite.animation

	var move_dir := 0.0
	if absf(target.velocity.x) > stop_threshold:
		move_dir = sign(target.velocity.x)

	var did_jump := false
	var jump_flag = target.get("did_jump_this_frame")
	if typeof(jump_flag) == TYPE_BOOL:
		did_jump = jump_flag

	var target_facing_left := facing_left
	if target_sprite:
		target_facing_left = target_sprite.flip_h

	state_queue.append({
		"move_dir": move_dir,
		"did_jump": did_jump,
		"attack_anim": attack_anim,
		"facing_left": target_facing_left
	})


func _apply_delayed_state(delayed: Dictionary, delta: float) -> void:
	var move_dir: float = delayed["move_dir"]
	velocity.x = move_dir * speed

	if absf(velocity.x) < stop_threshold:
		velocity.x = 0.0

	if delayed["did_jump"] and is_on_floor() and not force_fall:
		velocity.y = -jump_speed

	velocity.y += gravity * delta
	move_and_slide()

	if is_on_floor() and force_fall:
		force_fall = false

	_update_animation(delayed)


func _update_animation(delayed: Dictionary) -> void:
	var delayed_attack_anim: String = delayed["attack_anim"]
	var new_anim: String

	if delayed_attack_anim != "":
		new_anim = delayed_attack_anim
	elif not is_on_floor():
		new_anim = "Jump"
	elif absf(velocity.x) > stop_threshold:
		new_anim = "Running"
	else:
		new_anim = "Idle"

	if new_anim != current_animation:
		shadow_sprite.play(new_anim)
		current_animation = new_anim

	if absf(velocity.x) > stop_threshold:
		facing_left = velocity.x < 0
	else:
		facing_left = delayed["facing_left"]

	shadow_sprite.flip_h = facing_left


func spawn_afterimage() -> void:
	var after_image = afterimage_scene.instantiate()
	if not after_image:
		return

	get_tree().current_scene.add_child(after_image)
	after_image.global_transform = global_transform

	var sprite = after_image.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.animation = shadow_sprite.animation
		sprite.frame = shadow_sprite.frame
		sprite.flip_h = shadow_sprite.flip_h
		sprite.modulate = Color(0, 0, 0, afterimage_start_alpha)

		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, afterimage_lifetime)
		tween.tween_callback(after_image.queue_free)


func reset_queue() -> void:
	state_queue.clear()

	for i in range(follow_delay):
		state_queue.append({
			"move_dir": 0.0,
			"did_jump": false,
			"attack_anim": "",
			"facing_left": facing_left
		})

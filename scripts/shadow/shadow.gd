extends CharacterBody2D

const SHADOW_GROUNDED_MASK := 17
const SHADOW_FALL_MASK := 19
const SHADOW_RISE_MASK := 18
const SHADOW_AIR_SPRITE_Y := -26.0
const SHADOW_GROUNDED_SPRITE_Y := -24.0

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
@onready var outline_sprite: AnimatedSprite2D = $OutlineSprite

# --- Internal State ---
var state_queue: Array = []
var current_animation: String = ""
var facing_left := false
var afterimage_timer := 0.0
var force_fall := false
var min_bound_x := -INF
var max_bound_x := INF
var follow_enabled := true


func _ready() -> void:
	floor_snap_length = 2.0
	collision_mask = SHADOW_FALL_MASK

	reset_queue()
	_sync_outline_sprite()


func _physics_process(delta: float) -> void:
	if not target:
		_update_collision_mask()
		velocity.y += gravity * delta
		move_and_slide()
		return

	if not follow_enabled:
		velocity.x = 0.0
		_update_collision_mask()
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		_clamp_horizontal_bounds()

		if is_on_floor() and current_animation != "Idle":
			shadow_sprite.play("Idle")
			current_animation = "Idle"
		shadow_sprite.flip_h = facing_left
		shadow_sprite.position.y = SHADOW_GROUNDED_SPRITE_Y if is_on_floor() else SHADOW_AIR_SPRITE_Y
		_sync_outline_sprite()
		return

	_record_target_state(delta)

	if state_queue.size() > follow_delay:
		var delayed: Dictionary = state_queue.pop_front()
		_apply_delayed_state(delayed, delta)
	else:
		velocity.y += gravity * delta
		move_and_slide()
		_clamp_horizontal_bounds()

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
	var input_dir = target.get("move_input_dir")
	if typeof(input_dir) == TYPE_FLOAT and absf(input_dir) > 0.01:
		move_dir = sign(input_dir)
	elif absf(target.velocity.x) > stop_threshold:
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

	_update_collision_mask()
	velocity.y += gravity * delta
	_resolve_rising_wall_collision(delta)
	move_and_slide()
	_clamp_horizontal_bounds()
	_update_collision_mask()

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
	shadow_sprite.position.y = SHADOW_GROUNDED_SPRITE_Y if is_on_floor() else SHADOW_AIR_SPRITE_Y
	_sync_outline_sprite()


func _update_collision_mask() -> void:
	if velocity.y < 0.0:
		collision_mask = SHADOW_RISE_MASK
	elif is_on_floor() and _has_common_floor_beneath():
		collision_mask = SHADOW_GROUNDED_MASK
	else:
		collision_mask = SHADOW_FALL_MASK


func _has_common_floor_beneath() -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 96.0))
	query.collision_mask = 1
	query.exclude = [self]

	var hit := space_state.intersect_ray(query)
	return not hit.is_empty()


func _resolve_rising_wall_collision(delta: float) -> void:
	if velocity.y >= 0.0 or absf(velocity.x) < stop_threshold:
		return

	var collision_shape := $CollisionShape2D as CollisionShape2D
	if not collision_shape:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if not shape:
		return

	var shape_scale := collision_shape.global_scale.abs()
	var half_width := shape.size.x * 0.5 * shape_scale.x
	var half_height := shape.size.y * 0.5 * shape_scale.y
	var direction := signf(velocity.x)
	var center := collision_shape.global_position
	var edge_x := center.x + (half_width * direction)
	var cast_distance := absf(velocity.x * delta) + 2.0
	var sample_offsets := [
		-half_height * 0.55,
		0.0,
		half_height * 0.2
	]

	var nearest_hit: Dictionary = {}
	for offset_y in sample_offsets:
		var start := Vector2(edge_x, center.y + offset_y)
		var finish := start + Vector2(direction * cast_distance, 0.0)
		var hit := _intersect_common_solid(start, finish)
		if hit.is_empty():
			continue
		if nearest_hit.is_empty():
			nearest_hit = hit
		elif direction > 0.0 and hit.position.x < nearest_hit.position.x:
			nearest_hit = hit
		elif direction < 0.0 and hit.position.x > nearest_hit.position.x:
			nearest_hit = hit

	if nearest_hit.is_empty():
		return

	var body_left := center.x - half_width
	var body_right := center.x + half_width
	if direction > 0.0:
		global_position.x += nearest_hit.position.x - body_right - 0.5
	else:
		global_position.x += nearest_hit.position.x - body_left + 0.5
	velocity.x = 0.0


func _intersect_common_solid(start: Vector2, finish: Vector2) -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start, finish)
	query.collision_mask = 1
	query.exclude = [self]
	return space_state.intersect_ray(query)


func set_horizontal_bounds(left_x: float, right_x: float) -> void:
	min_bound_x = left_x
	max_bound_x = right_x


func set_follow_enabled(enabled: bool) -> void:
	follow_enabled = enabled
	if enabled:
		reset_queue()
		_sync_outline_sprite()
		return

	velocity.x = 0.0
	afterimage_timer = 0.0
	reset_queue()
	if is_on_floor():
		shadow_sprite.play("Idle")
		current_animation = "Idle"
	_sync_outline_sprite()


func _sync_outline_sprite() -> void:
	if outline_sprite == null or shadow_sprite == null:
		return

	if outline_sprite.animation != shadow_sprite.animation:
		outline_sprite.play(shadow_sprite.animation)
	elif not outline_sprite.is_playing() and shadow_sprite.is_playing():
		outline_sprite.play()

	outline_sprite.flip_h = shadow_sprite.flip_h
	outline_sprite.position = shadow_sprite.position
	outline_sprite.scale = shadow_sprite.scale
	outline_sprite.frame = shadow_sprite.frame
	outline_sprite.frame_progress = shadow_sprite.frame_progress

	if not shadow_sprite.is_playing():
		outline_sprite.pause()


func _clamp_horizontal_bounds() -> void:
	if not is_finite(min_bound_x) or not is_finite(max_bound_x):
		return

	var extents := _get_horizontal_extents()
	var min_origin_x := min_bound_x + extents.x
	var max_origin_x := max_bound_x - extents.y

	if global_position.x < min_origin_x:
		global_position.x = min_origin_x
		if velocity.x < 0.0:
			velocity.x = 0.0
	elif global_position.x > max_origin_x:
		global_position.x = max_origin_x
		if velocity.x > 0.0:
			velocity.x = 0.0


func _get_horizontal_extents() -> Vector2:
	var collision_shape := $CollisionShape2D as CollisionShape2D
	if not collision_shape:
		return Vector2.ZERO

	var shape := collision_shape.shape as RectangleShape2D
	if not shape:
		return Vector2.ZERO

	var half_width := shape.size.x * 0.5 * absf(global_scale.x)
	return Vector2(half_width - collision_shape.position.x, half_width + collision_shape.position.x)


func spawn_afterimage() -> void:
	var after_image = afterimage_scene.instantiate()
	if not after_image:
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(after_image)
	after_image.global_transform = global_transform

	var sprite = after_image.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.animation = shadow_sprite.animation
		sprite.frame = shadow_sprite.frame
		sprite.flip_h = shadow_sprite.flip_h
		sprite.position = shadow_sprite.position
		sprite.scale = shadow_sprite.scale
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


func reset_to_level_start(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	force_fall = false
	afterimage_timer = 0.0
	current_animation = ""
	reset_queue()

	if shadow_sprite:
		shadow_sprite.position.y = SHADOW_GROUNDED_SPRITE_Y
		shadow_sprite.play("Idle")

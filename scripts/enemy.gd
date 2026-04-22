# Enemy.gd
extends CharacterBody2D

signal defeated

@export var speed: float = 300.0
@export var gravity: float = 1100.0
@export var stop_distance: float = 34.0
@export var attack_range: float = 48.0
@export var attack_damage: int = 20
@export var attack_cooldown: float = 1.0
@export var attack_area_x_offset: float = 30.0
@export var max_health: int = 3

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionRange
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var target_player: CharacterBody2D = null
var player_in_range := false
var health: int
var is_dead := false
var is_attacking := false
var attack_cooldown_timer := 0.0
var facing_dir := 1
var death_settled := false
var defeat_emitted := false
var _starting_collision_layer := 0
var ai_enabled := true
var damage_enabled := true

func _ready() -> void:
	health = max_health
	_starting_collision_layer = collision_layer
	anim.play("Idle")

	detection_area.monitoring = true
	attack_area.monitoring = false
	_update_attack_side()

	if not detection_area.body_entered.is_connected(_on_detection_body_entered):
		detection_area.body_entered.connect(_on_detection_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_body_exited):
		detection_area.body_exited.connect(_on_detection_body_exited)

	if not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if is_dead:
		if not death_settled:
			if not is_on_floor():
				velocity.y += gravity * delta
			else:
				velocity = Vector2.ZERO
				death_settled = true
		else:
			velocity = Vector2.ZERO

		move_and_slide()
		return

	if not ai_enabled:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		anim.play("Idle")
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if _target_is_dead_or_invalid():
		_clear_target_and_stop()
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	if player_in_range and is_instance_valid(target_player):
		var dx := target_player.global_position.x - global_position.x
		var abs_dx := absf(dx)
		var engage_distance := _get_engage_distance()

		if dx > 0.0:
			facing_dir = 1
		elif dx < 0.0:
			facing_dir = -1

		anim.flip_h = facing_dir < 0
		_update_attack_side()

		if abs_dx <= engage_distance and attack_cooldown_timer <= 0.0:
			_start_attack()
		elif abs_dx > engage_distance:
			velocity.x = sign(dx) * speed
			anim.play("Run")
		else:
			velocity.x = 0.0
			anim.play("Idle")
	else:
		velocity.x = 0.0
		anim.play("Idle")

	move_and_slide()

func _target_is_dead_or_invalid() -> bool:
	if target_player == null:
		return false
	if not is_instance_valid(target_player):
		return true
	return target_player.get("is_dead") == true

func _clear_target_and_stop() -> void:
	target_player = null
	player_in_range = false
	is_attacking = false
	attack_area.monitoring = false
	velocity.x = 0.0
	anim.play("Idle")

func _get_engage_distance() -> float:
	return maxf(maxf(stop_distance, attack_range), _get_combined_body_half_widths())

func _get_combined_body_half_widths() -> float:
	if not is_instance_valid(target_player):
		return 0.0
	return _get_body_half_width(self) + _get_body_half_width(target_player) + 4.0

func _get_body_half_width(body: CharacterBody2D) -> float:
	if body == null:
		return 0.0

	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 0.0

	var scale_x := absf(collision_shape.global_scale.x)

	if collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		return rectangle.size.x * 0.5 * scale_x

	if collision_shape.shape is CapsuleShape2D:
		var capsule := collision_shape.shape as CapsuleShape2D
		return capsule.radius * scale_x

	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		return circle.radius * scale_x

	return 0.0

func _update_attack_side() -> void:
	attack_area.position.x = attack_area_x_offset * facing_dir
	if attack_shape and attack_shape.shape:
		attack_shape.position.x = absf(attack_shape.position.x) * facing_dir

func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	if enabled or is_dead:
		return

	target_player = null
	player_in_range = false
	is_attacking = false
	attack_cooldown_timer = 0.0
	attack_area.monitoring = false
	velocity.x = 0.0
	anim.play("Idle")

func set_damage_enabled(enabled: bool) -> void:
	damage_enabled = enabled

func _start_attack() -> void:
	is_attacking = true
	attack_cooldown_timer = attack_cooldown
	velocity.x = 0.0
	_update_attack_side()
	attack_area.monitoring = true
	anim.play("Attack")

func _apply_attack_hit_to_overlaps() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			if body.get("is_dead") == true:
				continue
			body.take_damage(attack_damage)
			break

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0 or not damage_enabled:
		return

	health = clampi(health - amount, 0, max_health)
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	target_player = null
	player_in_range = false
	death_settled = is_on_floor()

	velocity.x = 0.0
	if death_settled:
		velocity.y = 0.0

	detection_area.monitoring = false
	attack_area.monitoring = false
	collision_layer = 0

	anim.play("Death")

func _on_animation_finished() -> void:
	if anim.animation == "Attack":
		if not _target_is_dead_or_invalid():
			_apply_attack_hit_to_overlaps()
		attack_area.monitoring = false
		is_attacking = false
	elif anim.animation == "Death":
		anim.pause()
		if not defeat_emitted:
			defeat_emitted = true
			defeated.emit()

func _on_detection_body_entered(body: Node) -> void:
	if is_dead:
		return
	if body is CharacterBody2D and body.is_in_group("player"):
		if body.get("is_dead") == true:
			return
		target_player = body as CharacterBody2D
		player_in_range = true

func _on_detection_body_exited(body: Node) -> void:
	if body == target_player:
		target_player = null
		player_in_range = false


func reset_to_level_start(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = max_health
	is_dead = false
	is_attacking = false
	player_in_range = false
	target_player = null
	attack_cooldown_timer = 0.0
	death_settled = false
	defeat_emitted = false
	collision_layer = _starting_collision_layer
	detection_area.monitoring = true
	attack_area.monitoring = false
	anim.flip_h = false
	facing_dir = 1
	_update_attack_side()
	anim.play("Idle")

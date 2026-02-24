extends CharacterBody2D

@export var speed: float = 120.0
@export var stop_distance: float = 28.0
@export var attack_range: float = 40.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var attack_area_x_offset: float = 24.0
@export var max_health: int = 3

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionRange
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var target_player: CharacterBody2D = null
var player_in_range := false
var health: int
var is_dead := false
var is_attacking := false
var attack_cooldown_timer := 0.0
var facing_dir := 1 # 1 right, -1 left

func _ready() -> void:
	health = max_health
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
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player_in_range and is_instance_valid(target_player):
		var dx := target_player.global_position.x - global_position.x
		var abs_dx := absf(dx)

		if dx > 0.0:
			facing_dir = 1
		elif dx < 0.0:
			facing_dir = -1

		anim.flip_h = facing_dir < 0
		_update_attack_side()

		if abs_dx <= attack_range and attack_cooldown_timer <= 0.0:
			_start_attack()
		elif abs_dx > stop_distance:
			velocity.x = sign(dx) * speed
			velocity.y = 0.0
			anim.play("Run")
		else:
			velocity = Vector2.ZERO
			anim.play("Idle")
	else:
		velocity = Vector2.ZERO
		anim.play("Idle")

	move_and_slide()

func _update_attack_side() -> void:
	attack_area.position.x = attack_area_x_offset * facing_dir
	if attack_shape and attack_shape.shape:
		attack_shape.position.x = absf(attack_shape.position.x) * facing_dir

func _start_attack() -> void:
	is_attacking = true
	attack_cooldown_timer = attack_cooldown
	velocity = Vector2.ZERO
	_update_attack_side()
	attack_area.monitoring = true
	anim.play("Attack")

func _apply_attack_hit_to_overlaps() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			break

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = clampi(health - amount, 0, max_health)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	is_attacking = false
	target_player = null
	player_in_range = false
	velocity = Vector2.ZERO

	detection_area.monitoring = false
	attack_area.monitoring = false

	collision_layer = 0
	collision_mask = 0
	body_shape.disabled = true

	anim.play("Death")

func _on_animation_finished() -> void:
	if anim.animation == "Attack":
		_apply_attack_hit_to_overlaps()
		attack_area.monitoring = false
		is_attacking = false
	elif anim.animation == "Death":
		anim.pause()

func _on_detection_body_entered(body: Node) -> void:
	if is_dead:
		return
	if body is CharacterBody2D and body.is_in_group("player"):
		target_player = body as CharacterBody2D
		player_in_range = true

func _on_detection_body_exited(body: Node) -> void:
	if body == target_player:
		target_player = null
		player_in_range = false

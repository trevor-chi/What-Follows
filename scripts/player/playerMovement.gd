extends CharacterBody2D

signal health_changed(current: int, max_value: int)
signal died

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBarPivot/HealthBar

@export var speed := 400.0
@export var jumpVel := 750.0
@export var gravity := 1100.0

# Health
@export var max_health: int = 100
var health: int = 100

# Smoother ground movement
@export var accel := 2800.0
@export var decel := 4200.0
@export var attack_move_multiplier := 0.2 # % of move speed while attacking

var facing_dir := 1 # 1 = right, -1 = left
var was_on_floor := false
var jump_anim_finished := false
var did_jump_this_frame := false

# Attack combo state
var is_attacking := false
var attack_step := 0 # 0 = none, 1..3 = combo hit
var queued_next_attack := false


func _ready() -> void:
	anim.play("Idle")

	health = max_health
	_update_health_bar()
	health_changed.emit(health, max_health)
	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1f1f1f")
	bg.border_color = Color.BLACK
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	health_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("d94343")
	fill.set_corner_radius_all(6)
	health_bar.add_theme_stylebox_override("fill", fill)

	health_bar.add_theme_color_override("font_color", Color.WHITE)


	# Ensure finish signal is connected even if editor connection is missing.
	if not anim.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		anim.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _update_health_bar() -> void:
	health_bar.max_value = max_health
	health_bar.value = health

func play_anim(name: String) -> void:
	if anim.animation != name:
		anim.play(name)


func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	health = clampi(health - amount, 0, max_health)
	_update_health_bar()
	health_changed.emit(health, max_health)

	if health <= 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0:
		return

	health = clampi(health + amount, 0, max_health)
	_update_health_bar()
	health_changed.emit(health, max_health)


func start_attack(step: int) -> void:
	is_attacking = true
	attack_step = step
	queued_next_attack = false
	anim.play("Attack_%d" % attack_step)


func end_attack(direction: float, on_floor: bool) -> void:
	is_attacking = false
	attack_step = 0
	queued_next_attack = false

	if not on_floor:
		return

	if direction != 0:
		play_anim("Running")
	else:
		play_anim("Idle")


func _physics_process(delta: float) -> void:
	did_jump_this_frame = false

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump (allowed while attacking)
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jumpVel
		did_jump_this_frame = true

	# Attack input (ground combo)
	if Input.is_action_just_pressed("attack") and is_on_floor():
		if not is_attacking:
			start_attack(1)
		elif attack_step < 3:
			queued_next_attack = true

	# Horizontal movement (smoothed, including during attacks)
	var input_dir := Input.get_axis("move_left", "move_right")

	# Keep facing stable unless clear input
	if abs(input_dir) > 0.2:
		facing_dir = int(sign(input_dir))

	var target_speed := input_dir * speed
	if is_attacking:
		target_speed *= attack_move_multiplier

	# Smooth horizontal velocity
	if abs(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	move_and_slide()

	var on_floor := is_on_floor()

	# Safety fallback: recover if signal is missed.
	if is_attacking and not anim.is_playing():
		if queued_next_attack and attack_step < 3 and on_floor:
			start_attack(attack_step + 1)
		else:
			end_attack(input_dir, on_floor)

	# temp test for player damage
	if Input.is_action_just_pressed("damage"):
		take_damage(10)

	# Non-attack animation flow
	if not is_attacking:
		if was_on_floor and not on_floor:
			jump_anim_finished = false
			anim.play("Jump")
		elif not on_floor:
			if jump_anim_finished:
				anim.pause() # freeze last jump frame
		elif abs(input_dir) > 0.01:
			play_anim("Running")
		else:
			play_anim("Idle")

	anim.flip_h = facing_dir < 0
	was_on_floor = on_floor


func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "Jump":
		jump_anim_finished = true
		return

	if anim.animation.begins_with("Attack_"):
		var on_floor := is_on_floor()
		if queued_next_attack and attack_step < 3 and on_floor:
			start_attack(attack_step + 1)
		else:
			var direction := Input.get_axis("move_left", "move_right")
			end_attack(direction, on_floor)

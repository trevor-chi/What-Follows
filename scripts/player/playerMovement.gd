extends CharacterBody2D

signal health_changed(current: int, max_value: int)
signal died

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBarPivot/HealthBar
@onready var attack_area: Area2D = $AttackArea

@export var speed := 400.0
@export var jumpVel := 750.0
@export var gravity := 1100.0

# Health
@export var max_health: int = 100
@export var hurt_invuln_time: float = 0.25
var health: int = 100
var hurt_timer: float = 0.0
var is_dead: bool = false

# Smoother ground movement
@export var accel := 2800.0
@export var decel := 4200.0
@export var attack_move_multiplier := 0.2 # % of move speed while attacking

# Attack damage/hitbox settings
@export var attack_damage: int = 1
@export var attack_area_x_offset: float = 42.0

var facing_dir := 1 # 1 = right, -1 = left
var was_on_floor := false
var jump_anim_finished := false
var did_jump_this_frame := false

# Attack combo state
var is_attacking := false
var attack_step := 0 # 0 = none, 1..3 = combo hit
var queued_next_attack := false
var hit_targets_this_swing: Dictionary = {}

# store key ids
var keys: Array[String] = []

func _ready() -> void:
	anim.play("Idle")

	# Ensure enemies can find this player
	if not is_in_group("player"):
		add_to_group("player")

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

	if not anim.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		anim.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

	attack_area.monitoring = false
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	_update_attack_area_side()

func _update_health_bar() -> void:
	health_bar.max_value = max_health
	health_bar.value = health

func play_anim(name: String) -> void:
	if anim.animation != name:
		anim.play(name)

func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	if hurt_timer > 0.0:
		return

	health = clampi(health - amount, 0, max_health)
	hurt_timer = hurt_invuln_time
	_update_health_bar()
	health_changed.emit(health, max_health)

	if health <= 0:
		_on_died()

func heal(amount: int) -> void:
	if amount <= 0 or is_dead:
		return

	health = clampi(health + amount, 0, max_health)
	_update_health_bar()
	health_changed.emit(health, max_health)

func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	queued_next_attack = false
	attack_step = 0
	attack_area.monitoring = false
	velocity = Vector2.ZERO

	died.emit()
	anim.play("Death")

func start_attack(step: int) -> void:
	if is_dead:
		return

	is_attacking = true
	attack_step = step
	queued_next_attack = false
	hit_targets_this_swing.clear()

	_update_attack_area_side()
	attack_area.monitoring = true
	anim.play("Attack_%d" % attack_step)

func end_attack(direction: float, on_floor: bool) -> void:
	is_attacking = false
	attack_step = 0
	queued_next_attack = false
	hit_targets_this_swing.clear()
	attack_area.monitoring = false

	if not on_floor:
		return

	if direction != 0:
		play_anim("Running")
	else:
		play_anim("Idle")

func _update_attack_area_side() -> void:
	attack_area.position.x = attack_area_x_offset * facing_dir

func _apply_attack_hit_to_overlaps() -> void:
	for body in attack_area.get_overlapping_bodies():
		if not body.is_in_group("enemy"):
			continue
		if not body.has_method("take_damage"):
			continue
		if hit_targets_this_swing.has(body):
			continue

		hit_targets_this_swing[body] = true
		body.take_damage(attack_damage)

func _physics_process(delta: float) -> void:
	if hurt_timer > 0.0:
		hurt_timer -= delta

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	did_jump_this_frame = false

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jumpVel
		did_jump_this_frame = true

	if Input.is_action_just_pressed("attack") and is_on_floor():
		if not is_attacking:
			start_attack(1)
		elif attack_step < 3:
			queued_next_attack = true

	var input_dir := Input.get_axis("move_left", "move_right")

	if abs(input_dir) > 0.2:
		facing_dir = int(sign(input_dir))
		_update_attack_area_side()

	var target_speed := input_dir * speed
	if is_attacking:
		target_speed *= attack_move_multiplier

	if abs(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	move_and_slide()

	var on_floor := is_on_floor()

	if is_attacking and not anim.is_playing():
		if queued_next_attack and attack_step < 3 and on_floor:
			start_attack(attack_step + 1)
		else:
			end_attack(input_dir, on_floor)

	if not is_attacking:
		if was_on_floor and not on_floor:
			jump_anim_finished = false
			anim.play("Jump")
		elif not on_floor:
			if jump_anim_finished:
				anim.pause()
		elif abs(input_dir) > 0.01:
			play_anim("Running")
		else:
			play_anim("Idle")

	anim.flip_h = facing_dir < 0
	was_on_floor = on_floor

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_dead:
		if anim.animation == "Death":
			anim.pause()
		return

	if anim.animation == "Jump":
		jump_anim_finished = true
		return

	if anim.animation.begins_with("Attack_"):
		_apply_attack_hit_to_overlaps()

		var on_floor := is_on_floor()
		if queued_next_attack and attack_step < 3 and on_floor:
			start_attack(attack_step + 1)
		else:
			var direction := Input.get_axis("move_left", "move_right")
			end_attack(direction, on_floor)

func _on_attack_area_body_entered(_body: Node) -> void:
	# No immediate damage; damage is applied when attack animation finishes.
	pass
	
func add_key(id: String) -> void:
	if not keys.has(id):
		keys.append(id)

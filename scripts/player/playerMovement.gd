extends CharacterBody2D

@onready var anim := $AnimatedSprite2D

@export var speed := 400.0
@export var jumpVel := 750.0
@export var gravity := 1100.0

var facing_dir := 1          # 1 = right, -1 = left
var was_on_floor := false
var jump_anim_finished := false

func _ready():
	anim.play("Idle")

func play_anim(name: String):
	if anim.animation != name:
		anim.play(name)

func _physics_process(delta):
	# --------------------
	# MOVEMENT
	# --------------------

	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# jump input
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jumpVel

	# horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing_dir = direction

	velocity.x = direction * speed

	# move FIRST to update floor state
	move_and_slide()

	# --------------------
	# STATE CHECKS
	# --------------------

	var on_floor := is_on_floor()

	# --------------------
	# ANIMATIONS
	# --------------------

	# takeoff (play jump ONCE)
	if was_on_floor and not on_floor:
		jump_anim_finished = false
		anim.play("Jump")

	# airborne
	elif not on_floor:
		if jump_anim_finished:
			anim.pause()  # freeze last jump frame

	# grounded
	elif direction != 0:
		play_anim("Running")
	else:
		play_anim("Idle")

	anim.flip_h = facing_dir < 0

	# update state
	was_on_floor = on_floor


# --------------------
# SIGNALS
# --------------------

func _on_animated_sprite_2d_animation_finished():
	if anim.animation == "Jump":
		jump_anim_finished = true

# Key.gd
extends Area2D

@export var key_id: String = "gold_key"
@export var follow_offset: Vector2 = Vector2(18, -20)
@export var follow_lerp_speed: float = 3.0
@export var reveal_drop_height: float = 80.0
@export var reveal_duration: float = 0.55
@export var bob_height: float = 10.0
@export var bob_speed: float = 2.2
@export var reveal_scale_multiplier: float = 1.45
@export var idle_pulse_amount: float = 0.08
@export var idle_glow_amount: float = 0.2

@onready var sprite: AnimatedSprite2D = $Key
@onready var shape: CollisionShape2D = $CollisionShape2D

var holder: CharacterBody2D = null
var collected: bool = false
var being_used: bool = false
var resting_position: Vector2
var bob_time := 0.0
var bobbing_enabled := false
var reveal_tween: Tween = null
var landing_tween: Tween = null
var base_sprite_scale := Vector2.ONE

func _ready() -> void:
	resting_position = global_position
	base_sprite_scale = sprite.scale
	body_entered.connect(_on_body_entered)
	set_available(false)

func _process(delta: float) -> void:
	if collected and is_instance_valid(holder) and not being_used:
		var target_pos := holder.global_position + follow_offset
		var t := clampf(follow_lerp_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(target_pos, t)
	elif bobbing_enabled and visible and not being_used:
		bob_time += delta * bob_speed
		global_position = resting_position + Vector2(0.0, sin(bob_time) * bob_height)
		var pulse := (sin(bob_time * 1.6) + 1.0) * 0.5
		sprite.scale = base_sprite_scale * (1.0 + (idle_pulse_amount * pulse))
		var glow := 1.0 + (idle_glow_amount * pulse)
		sprite.modulate = Color(glow, glow, glow, 1.0)

func set_available(enabled: bool) -> void:
	if reveal_tween:
		reveal_tween.kill()
		reveal_tween = null
	if landing_tween:
		landing_tween.kill()
		landing_tween = null

	bobbing_enabled = false
	visible = enabled
	monitoring = enabled
	shape.set_deferred("disabled", not enabled)

	if enabled:
		resting_position = global_position
		global_position = resting_position + Vector2(0.0, -reveal_drop_height)
		scale = Vector2.ONE
		bob_time = 0.0
		sprite.scale = base_sprite_scale * reveal_scale_multiplier
		sprite.modulate = Color(1.8, 1.8, 1.8, 0.0)
		sprite.play("Idle")
		reveal_tween = create_tween()
		reveal_tween.set_trans(Tween.TRANS_BOUNCE)
		reveal_tween.set_ease(Tween.EASE_OUT)
		reveal_tween.parallel().tween_property(self, "global_position", resting_position, reveal_duration)
		reveal_tween.parallel().tween_property(sprite, "scale", base_sprite_scale, reveal_duration)
		reveal_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, reveal_duration * 0.85)
		reveal_tween.finished.connect(_on_reveal_finished)
	else:
		global_position = resting_position
		sprite.scale = base_sprite_scale
		sprite.modulate = Color.WHITE
		sprite.stop()

func _on_body_entered(body: Node) -> void:
	if collected or being_used:
		return

	if body.is_in_group("player") and body.has_method("add_key"):
		bobbing_enabled = false
		sprite.scale = base_sprite_scale
		sprite.modulate = Color.WHITE
		holder = body as CharacterBody2D
		collected = true
		monitoring = false
		shape.set_deferred("disabled", true)
		body.add_key(key_id, self)

func use_on_door(target_pos: Vector2) -> void:
	if being_used:
		return

	being_used = true
	collected = false
	holder = null
	bobbing_enabled = false

	if reveal_tween:
		reveal_tween.kill()
		reveal_tween = null
	if landing_tween:
		landing_tween.kill()
		landing_tween = null

	sprite.scale = base_sprite_scale
	sprite.modulate = Color.WHITE

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", target_pos, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.2)
	tween.tween_callback(queue_free)

func _on_reveal_finished() -> void:
	reveal_tween = null
	if visible and not collected and not being_used:
		landing_tween = create_tween()
		landing_tween.set_trans(Tween.TRANS_BACK)
		landing_tween.set_ease(Tween.EASE_OUT)
		landing_tween.tween_property(sprite, "scale", base_sprite_scale * 1.22, 0.12)
		landing_tween.parallel().tween_property(sprite, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.12)
		landing_tween.tween_property(sprite, "scale", base_sprite_scale * 0.96, 0.10)
		landing_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.10)
		landing_tween.tween_callback(_start_bobbing)

func _start_bobbing() -> void:
	landing_tween = null
	if visible and not collected and not being_used:
		bobbing_enabled = true


func reset_to_level_start(spawn_position: Vector2, available: bool = false) -> void:
	holder = null
	collected = false
	being_used = false
	resting_position = spawn_position
	global_position = spawn_position
	bob_time = 0.0
	scale = Vector2.ONE
	sprite.scale = base_sprite_scale
	sprite.modulate = Color.WHITE
	set_available(available)

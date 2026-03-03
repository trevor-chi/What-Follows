extends Area2D

@export var kill_delay: float = 0.50

# Base look
@export var base_color: Color = Color(0.03, 0.04, 0.08, 0.55)

# Visual motion (no shader)
@export var pulse_alpha: float = 0.05
@export var pulse_speed: float = 0.35
@export var wobble_amount: float = 0.015
@export var wobble_speed: float = 0.22
@export var danger_alpha_boost: float = 0.22

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var shadow_rect: ColorRect = $ColorRect

# Tracks bodies currently inside and their latest enter token
var _inside_tokens: Dictionary = {}

# Visual state
var _player_inside: bool = false
var _inside_time: float = 0.0
var _flicker: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_color_rect_to_collision()

	shadow_rect.color = base_color
	shadow_rect.pivot_offset = shadow_rect.size * 0.5

	_rng.randomize()
	_start_flicker_loop()

func _process(delta: float) -> void:
	if _player_inside:
		_inside_time += delta
	else:
		_inside_time = maxf(_inside_time - delta * 2.0, 0.0)

	var danger: float = clampf(_inside_time / maxf(kill_delay, 0.001), 0.0, 1.0)
	var t: float = float(Time.get_ticks_msec()) * 0.001

	var pulse: float = sin(t * TAU * pulse_speed) * pulse_alpha
	_flicker = move_toward(_flicker, 0.0, delta * 0.2)

	var c: Color = base_color
	c.a = clampf(base_color.a + pulse + _flicker + (danger * danger_alpha_boost), 0.0, 0.95)
	shadow_rect.color = c

	var s: float = 1.0 + sin(t * TAU * wobble_speed) * wobble_amount
	shadow_rect.scale = Vector2.ONE * s

func _sync_color_rect_to_collision() -> void:
	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		push_warning("ShadowArea expects RectangleShape2D when using ColorRect.")
		return

	var size: Vector2 = rect_shape.size
	shadow_rect.size = size
	shadow_rect.position = collision_shape.position - (size * 0.5)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var token: int = int(_inside_tokens.get(body, 0)) + 1
	_inside_tokens[body] = token
	_player_inside = true

	_kill_after_delay(body, token)

func _on_body_exited(body: Node) -> void:
	if _inside_tokens.has(body):
		_inside_tokens.erase(body)

	_player_inside = _inside_tokens.size() > 0
	if not _player_inside:
		_inside_time = 0.0

func _kill_after_delay(body: Node, token: int) -> void:
	await get_tree().create_timer(kill_delay).timeout

	if not is_instance_valid(body):
		return
	if not _inside_tokens.has(body):
		return

	var current_token: int = int(_inside_tokens.get(body, -1))
	if current_token != token:
		return # stale timer

	if body.has_method("die"):
		body.die()

func _start_flicker_loop() -> void:
	while is_inside_tree():
		var wait_time: float = _rng.randf_range(0.18, 0.60)
		await get_tree().create_timer(wait_time).timeout
		if _player_inside:
			_flicker += _rng.randf_range(-0.03, 0.05)

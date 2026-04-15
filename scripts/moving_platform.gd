extends AnimatableBody2D

@export var travel_offset := Vector2(280.0, 0.0)
@export var cycle_duration := 2.4

var _start_position := Vector2.ZERO
var _travel_clock := 0.0


func _ready() -> void:
	_start_position = global_position
	reset_to_start()


func _physics_process(delta: float) -> void:
	if cycle_duration <= 0.0:
		return

	_travel_clock = fposmod(_travel_clock + delta, cycle_duration)
	var phase := _travel_clock / cycle_duration
	var movement_weight := 0.5 - (0.5 * cos(phase * TAU))
	global_position = _start_position + (travel_offset * movement_weight)


func reset_to_start() -> void:
	_travel_clock = 0.0
	global_position = _start_position


func configure_motion(start_position: Vector2, new_travel_offset: Vector2) -> void:
	_start_position = start_position
	travel_offset = new_travel_offset
	reset_to_start()

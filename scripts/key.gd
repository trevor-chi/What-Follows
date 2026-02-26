extends Area2D

@export var key_id: String = "gold_key"
@export var follow_offset: Vector2 = Vector2(18, -20)
@export var follow_lerp_speed: float = 3.0 # lower = looser follow

@onready var sprite: AnimatedSprite2D = $Key
@onready var shape: CollisionShape2D = $CollisionShape2D

var holder: CharacterBody2D = null
var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.play("Idle")

func _process(delta: float) -> void:
	if collected and is_instance_valid(holder):
		var target_pos := holder.global_position + follow_offset
		var t := clampf(follow_lerp_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(target_pos, t)

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if body.is_in_group("player"):
		holder = body as CharacterBody2D
		collected = true

		# Prevent re-pickup/collision, but keep key visible.
		monitoring = false
		shape.set_deferred("disabled", true)

		# Add to player inventory.
		if holder.has_method("add_key"):
			holder.add_key(key_id)

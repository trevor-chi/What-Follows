extends Area2D

@export var key_id: String = "gold_key"
@export var follow_offset: Vector2 = Vector2(18, -20)
@export var follow_lerp_speed: float = 3.0 # lower = looser follow

@onready var sprite: AnimatedSprite2D = $Key
@onready var shape: CollisionShape2D = $CollisionShape2D

var holder: CharacterBody2D = null
var collected: bool = false
var being_used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.play("Idle")

func _process(delta: float) -> void:
	if collected and is_instance_valid(holder) and not being_used:
		var target_pos := holder.global_position + follow_offset
		var t := clampf(follow_lerp_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(target_pos, t)

func _on_body_entered(body: Node) -> void:
	if collected or being_used:
		return

	if body.is_in_group("player") and body.has_method("add_key"):
		holder = body as CharacterBody2D
		collected = true

		# Prevent re-pickup/collision, but keep key visible.
		monitoring = false
		shape.set_deferred("disabled", true)

		# Add to player inventory and store this key node.
		body.add_key(key_id, self)

func use_on_door(target_pos: Vector2) -> void:
	if being_used:
		return

	being_used = true
	collected = false
	holder = null

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", target_pos, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.2)
	tween.tween_callback(queue_free)

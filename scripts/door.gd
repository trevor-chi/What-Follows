extends Area2D

@export var required_key: String = "gold_key"
@export var key_insert_offset: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var is_open := false
var is_unlocking := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if is_open or is_unlocking:
		return

	if not body.is_in_group("player"):
		return

	if not body.has_method("has_key") or not body.has_method("consume_key"):
		return

	if not body.has_key(required_key):
		return

	is_unlocking = true

	var key_node: Node = body.consume_key(required_key)
	if key_node != null and key_node.has_method("use_on_door"):
		key_node.use_on_door(global_position + key_insert_offset)
		await get_tree().create_timer(0.2).timeout

	open_door()

func open_door() -> void:
	is_open = true
	is_unlocking = false
	monitoring = false
	shape.set_deferred("disabled", true)
	sprite.play("Open")

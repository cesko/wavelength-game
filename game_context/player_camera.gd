extends Camera2D

## The node this camera should follow
@export var target: Node2D

## Horizontal offset from the target
@export var offset_x: float = 0.0

## Fixed Y position for the camera
@export var fixed_y: float = 0.0

func _ready() -> void:
	# Optionally initialize fixed_y to the camera's starting position
	if fixed_y == 0.0:
		fixed_y = global_position.y

func _process(_delta: float) -> void:
	if not target:
		return

	global_position = Vector2(target.global_position.x + offset_x, fixed_y)

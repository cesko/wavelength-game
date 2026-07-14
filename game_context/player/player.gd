extends CharacterBody2D

## Forward Speed
@export var speed:float = 500

## Acceleration due to thrust
@export var thrust:float = 700

## Acceleration due to gravity
@export var gravity:float = 700

## player size
@export var size:float = 10.0

## emmitted when the character dies
signal died

@onready var player_input: Node = $PlayerInput
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_alive = true

func _ready() -> void:
	$Sprite2D.scale = Vector2(size/100.0,size/100.0)
	$TrackingLine2D.width = size
	$CollisionShape2D.shape.radius = size/2.0

func _physics_process(delta: float) -> void:
	
	if not is_alive:
		return
	
	velocity.x = speed
	
	if player_input.apply_thrust:
		velocity.y = velocity.y - thrust*delta
	else:
		velocity.y = velocity.y + gravity*delta

	move_and_slide()

	# Check for collisions
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			on_collision(collision)


func on_collision(_collision: KinematicCollision2D) -> void:
	die()

func get_distance() -> float:
	return global_position.x

func get_actions() -> float:
	return player_input.thrust_counter

func die():
	is_alive = false
	animation_player.play("death")
	died.emit()

	
	

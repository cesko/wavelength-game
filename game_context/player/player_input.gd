extends Node

var apply_thrust:bool = false
var thrust_counter:int = 0

var thrust_action_name = "thrust"

func _process(_delta: float) -> void:
	if Input.is_action_pressed(thrust_action_name):
		apply_thrust = true
		if Input.is_action_just_pressed(thrust_action_name):
			thrust_counter += 1		
	else:
		apply_thrust = false
	


#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed(thrust_action_name):
		#apply_thrust = true
		#thrust_counter += 1
	#if event.is_action_released(thrust_action_name):
		#apply_thrust = false
	

extends Node

var apply_thrust:bool = false
var thrust_counter:int = 0

var thrust_action_name = "thrust"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(thrust_action_name):
		apply_thrust = true
		thrust_counter += 1
	if event.is_action_released(thrust_action_name):
		apply_thrust = false
	

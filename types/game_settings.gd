extends Resource
class_name GameSettings

@export var speed:float = 500
@export var thrust:float = 700
@export var gravity:float = 700
@export var level_seed:int = -1

# --- PRESETS ---

func _scale_motion_settings(factor):
	speed = speed * factor
	thrust = thrust * factor
	gravity = gravity * factor

static func easy():
	var gs = GameSettings.new()
	gs._scale_motion_settings(0.6)
	return gs

static func normal():
	return GameSettings.new()
	
static func hard():
	var gs = GameSettings.new()
	gs._scale_motion_settings(1.4)
	return gs

static func sinucidal():
	var gs = GameSettings.new()
	gs._scale_motion_settings(2.0)
	return gs	

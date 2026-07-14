extends Resource
class_name GameSettings

enum Difficulty {UNKNOWN, EASY, NORMAL, HARD, SINUCIDAL}

@export var speed:float = 600
@export var thrust:float = 800
@export var gravity:float = 800
@export var level_seed:int = -1

var difficulty:Difficulty = Difficulty.UNKNOWN

# --- PRESETS ---

func _scale_motion_settings(factor):
	speed = speed * factor
	thrust = thrust * factor
	gravity = gravity * factor

static func easy():
	var gs = GameSettings.new()
	gs._scale_motion_settings(0.6)
	gs.difficulty = Difficulty.EASY
	return gs

static func normal():
	var gs =GameSettings.new()
	gs.difficulty = Difficulty.NORMAL
	return gs
	
static func hard():
	var gs = GameSettings.new()
	gs._scale_motion_settings(1.4)
	gs.difficulty = Difficulty.HARD
	return gs

static func sinucidal():
	var gs = GameSettings.new()
	gs._scale_motion_settings(2.0)
	gs.difficulty = Difficulty.SINUCIDAL
	return gs	

extends Node

class_name EnvironmentProfile

var center:Array[float]
var tunnel_height:Array[float]

var ceiling_profile:Array[float]
var ground_profile:Array[float]

var rng:RandomNumberGenerator
var seed_value:int

const CENTER_DEVIATION:float = 60
const CENTER_OFFSET_MAX:float = 200
const MEAN_TUNNEL_HEIGHT:float = 700
const TUNNEL_HEIGHT_DEVIATION:float = 200
const TUNNEL_MIN_HEIGHT:float = 250

const CEILING_MIN = -430
const GROUND_MIN = 430

func _init(start_length:float, total_length:float, step_size:float = 50, rng_seed:int = -1) -> void:
	rng = RandomNumberGenerator.new()
	if rng_seed == -1:
		rng.randomize()
		seed_value = rng.seed
	else:
		seed_value = rng_seed
		rng.seed = seed_value

	self._generate_start(ceili(start_length/step_size))
	self._generate_random(ceili((total_length-start_length)/step_size))

func _generate_start(steps:int) -> void:
	for i in range(steps):
		self.center.append(0)
		self.tunnel_height.append(MEAN_TUNNEL_HEIGHT)
		self.ceiling_profile.append(0 - MEAN_TUNNEL_HEIGHT/2)
		self.ground_profile.append(0 + MEAN_TUNNEL_HEIGHT/2)

func _generate_random(steps:int) -> void:
	for i in range(steps):
		_extend_unit_step()

func _extend_unit_step() -> void:
	var new_center = self.center[-1] + rng.randfn(0.0, CENTER_DEVIATION)
	new_center = clamp(new_center, -CENTER_OFFSET_MAX, CENTER_OFFSET_MAX)
	# BUG FIX: was using self.center[-1] instead of a fixed mean
	var new_tunnel_height = rng.randfn(MEAN_TUNNEL_HEIGHT, TUNNEL_HEIGHT_DEVIATION)

	self.center.append(new_center) 
	self.tunnel_height.append(max(TUNNEL_MIN_HEIGHT, new_tunnel_height))

	self.ceiling_profile.append( max(new_center - new_tunnel_height/2, CEILING_MIN) )
	self.ground_profile.append( min(new_center + new_tunnel_height/2, GROUND_MIN) )

# Helper for extending later as player progresses
func extend(additional_length:float, step_size:float = 50) -> void:
	var steps = ceili(additional_length/step_size)
	_generate_random(steps)

func trim_front(steps:int) -> void:
	steps = clamp(steps, 0, center.size() - 1)
	if steps <= 0:
		return
	center = center.slice(steps)
	tunnel_height = tunnel_height.slice(steps)
	ceiling_profile = ceiling_profile.slice(steps)
	ground_profile = ground_profile.slice(steps)

func get_step_count() -> int:
	return center.size()

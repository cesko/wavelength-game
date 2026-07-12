extends Resource
class_name Score

var distance
var actions

const DISTANCE_FACTOR = 0.1

func score() -> int:
	var raw_score = distance * DISTANCE_FACTOR	
	var score_value = floor(raw_score)
	return score_value

func energy() -> float:
	return score() / actions

extends Node

const SAVE_PATH: String = "user://highscores.save"
const MAX_SCORES_PER_DIFFICULTY: int = 10

# Dictionary mapping Difficulty -> Array of {"name": String, "score": int}
var _scores: Dictionary = {
	GameSettings.Difficulty.EASY: [],
	GameSettings.Difficulty.NORMAL: [],
	GameSettings.Difficulty.HARD: [],
	GameSettings.Difficulty.SINUCIDAL: []
}

signal highscore_update()

func _ready() -> void:
	load_scores()


## Adds a new score to the given difficulty list, keeping it sorted
## and trimmed to MAX_SCORES_PER_DIFFICULTY.
## Returns true if the score made it onto the list.
func add_score(difficulty: GameSettings.Difficulty, player_name: String, score: int) -> bool:
	print("adding scre for ", player_name)
	if not _scores.has(difficulty):
		push_error("Invalid difficulty: %s" % difficulty)
		return false

	var list: Array = _scores[difficulty]

	var new_entry := {"name": player_name, "score": score}
	list.append(new_entry)
	list.sort_custom(_sort_scores_descending)

	var made_it := list.find(new_entry) < MAX_SCORES_PER_DIFFICULTY

	if list.size() > MAX_SCORES_PER_DIFFICULTY:
		list.resize(MAX_SCORES_PER_DIFFICULTY)

	save_scores()
	highscore_update.emit()
	return made_it


## Returns a sorted (descending) copy of the score list for the given difficulty.
## Each entry is a Dictionary: {"name": String, "score": int}
func get_top_scores(difficulty: GameSettings.Difficulty, limit: int = -1) -> Array:
	if not _scores.has(difficulty):
		push_error("Invalid difficulty: %s" % difficulty)
		return []

	var list: Array = _scores[difficulty].duplicate(true)
	list.sort_custom(_sort_scores_descending)

	if limit >= 0 and limit < list.size():
		list = list.slice(0, limit)

	return list


## Returns the highest score value for a given difficulty, or 0 if none exist.
func get_high_score(difficulty: GameSettings.Difficulty) -> int:
	var top := get_top_scores(difficulty, 1)
	if top.is_empty():
		return 0
	return top[0]["score"]


## Checks if a value would qualify for the leaderboard without adding it.
func is_high_score(difficulty: GameSettings.Difficulty, score: int) -> bool:
	var list: Array = _scores.get(difficulty, [])
	if list.size() < MAX_SCORES_PER_DIFFICULTY:
		return true

	var lowest_entry: Dictionary = list[list.size() - 1]
	return score > lowest_entry["score"]


func clear_scores(difficulty: GameSettings.Difficulty) -> void:
	if _scores.has(difficulty):
		_scores[difficulty] = []
		save_scores()


func clear_all_scores() -> void:
	for key in _scores.keys():
		_scores[key] = []
	save_scores()


func _sort_scores_descending(a: Dictionary, b: Dictionary) -> bool:
	return a["score"] > b["score"]


## --- Persistence ---

func save_scores() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(_scores)
		file.close()
		highscore_update.emit()
	else:
		push_error("Failed to save high scores: %s" % FileAccess.get_open_error())


func load_scores() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to load high scores: %s" % FileAccess.get_open_error())
		return

	var loaded_data: Dictionary = file.get_var()
	file.close()

	for difficulty_key in _scores.keys():
		if loaded_data.has(difficulty_key):
			var list: Array = loaded_data[difficulty_key]
			list.sort_custom(_sort_scores_descending)
			_scores[difficulty_key] = list

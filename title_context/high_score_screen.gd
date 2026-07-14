extends Control

@onready var easy_scoreboard: Label = $VBoxContainer/HBoxContainer/EasyList/EasyScoreboard
@onready var normal_scoreboard: Label = $VBoxContainer/HBoxContainer/NormalList/NormalScoreboard
@onready var hard_scoreboard: Label = $VBoxContainer/HBoxContainer/HardList/HardScoreboard
@onready var sinuscidal_scoreboard: Label = $VBoxContainer/HBoxContainer/SinuscidalList/SinuscidalScoreboard

@onready var scoreboard_map = {
	GameSettings.Difficulty.EASY: easy_scoreboard,
	GameSettings.Difficulty.NORMAL: normal_scoreboard,
	GameSettings.Difficulty.HARD: hard_scoreboard,
	GameSettings.Difficulty.SINUCIDAL: sinuscidal_scoreboard
}

const MAX_LINES = 4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	HighscoreManager.highscore_update.connect(_on_highscore_update)
	update()
	
func update():
	
	for difficulty in scoreboard_map.keys():
		var scores = HighscoreManager.get_top_scores(difficulty)
		var score_text = ""
		var score_counter = 0
		for s in scores:
			score_text += str(s["score"]) + "\n"
			score_counter += 1
			if score_counter >= MAX_LINES:
				break
		scoreboard_map[difficulty].text = score_text

func _on_highscore_update():
	update()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_reset_button_pressed():
	HighscoreManager.clear_all_scores()

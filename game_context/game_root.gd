extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Camera2D
@onready var environment: Node2D = $Environment

@onready var gameover_ui: Control = $CanvasLayer/GameoverUi


var game_settings:GameSettings


signal quit_game()
signal play_again()
signal new_score(Score)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_apply_game_settings(game_settings)
	gameover_ui.hide()
	gameover_ui.play_again_button_pressed.connect(func (): play_again.emit())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _apply_game_settings(gs:GameSettings) -> void:
	if game_settings:
		player.speed = gs.speed
		player.thrust = gs.thrust
		player.gravity = gs.gravity

func show_game_over_screen() -> void:
	print("GAME OVER")
	print("Final Score: ", get_score().score())
	
func _on_player_died() -> void:
	show_game_over_screen()
	new_score.emit(get_score())
	gameover_ui.show()
	gameover_ui.set_score(get_score())
	pass
	

func get_score() -> Score:
	var score = Score.new()
	score.distance = player.global_position.x
	return score

func _on_quit() -> void:
	quit_game.emit()

extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Camera2D
@onready var environment: Node2D = $Environment

@onready var gameover_ui: Control = $CanvasLayer/GameoverUi
@onready var paused_ui: Control = $CanvasLayer/PausedUI
@onready var start_paused_ui: Control = $CanvasLayer/StartPaused
@onready var in_game_ui: Control = $CanvasLayer/InGameUI


enum GameStatus {STARTING, RUNNING, PAUSED, GAME_OVER}
var _game_status:GameStatus

var game_settings:GameSettings

signal quit_game()
signal play_again()
signal new_score(Score)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # make sure to set children to be paused to "Pausable"
	
	_apply_game_settings(game_settings)
	gameover_ui.hide()
	call_deferred("freeze_for_start_up")	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	in_game_ui.set_score(get_score())
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	
	if _game_status == GameStatus.STARTING:
		if event.is_action_pressed("thrust"):
			unpause()

func freeze_for_start_up():
	_game_status = GameStatus.RUNNING
	pause()
	paused_ui.hide()
	_game_status = GameStatus.STARTING

func pause():
	if _game_status != GameStatus.RUNNING:
		return
	_game_status = GameStatus.PAUSED
	get_tree().paused = true
	paused_ui.show()

func unpause():
	if _game_status != GameStatus.PAUSED and _game_status != GameStatus.STARTING:
		return
	_game_status = GameStatus.RUNNING
	get_tree().paused = false
	paused_ui.hide()
	start_paused_ui.hide()

func toggle_pause():
	if _game_status == GameStatus.RUNNING:
		pause()
	elif _game_status == GameStatus.PAUSED or _game_status == GameStatus.STARTING:
		unpause()
	
func get_score() -> Score:
	var score = Score.new()
	score.distance = player.get_distance()
	score.actions = player.get_actions()
	return score
	
func _apply_game_settings(gs:GameSettings) -> void:
	if game_settings:
		player.speed = gs.speed
		player.thrust = gs.thrust
		player.gravity = gs.gravity
		environment.level_seed = gs.level_seed

func _show_game_over_screen() -> void:
	_game_status = GameStatus.GAME_OVER
	gameover_ui.show()
	gameover_ui.set_score(get_score())
	
func _on_player_died() -> void:
	_show_game_over_screen()
	new_score.emit(get_score())	
	pass

func _on_quit() -> void:
	unpause()
	quit_game.emit()

func _on_gameover_ui_play_again_button_pressed() -> void:
	play_again.emit()

extends Control

signal quit_button_pressed()
signal play_again_button_pressed()

@onready var score_display: Label = $TitleScreen/PanelContainer/VBoxContainer/HBoxContainer/PanelContainer/VBoxContainer2/ScoreDisplay
@onready var actions_display: Label = $TitleScreen/PanelContainer/VBoxContainer/HBoxContainer/PanelContainer/VBoxContainer2/ActionsDisplay
@onready var play_again_button: Button = $TitleScreen/PanelContainer/VBoxContainer/HBoxContainer/VBoxContainer/PlayAgain
@onready var quit_button: Button = $TitleScreen/PanelContainer/VBoxContainer/HBoxContainer/VBoxContainer/Quit


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_again_button.grab_focus()
	play_again_button.pressed.connect(func (): play_again_button_pressed.emit())
	quit_button.pressed.connect(func(): quit_button_pressed.emit())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_score(score:Score) -> void:
	score_display.text = str(score.score())

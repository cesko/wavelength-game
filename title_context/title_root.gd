extends Control

@export var initial_focus:Control

signal play(GameSettings)


@onready var screens = {
	"title": $TitleScreen,
	"play": $PlayScreen
}

var initial_screen = "title"
var current_screen

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide_all_screens()
	switch_to_screen(initial_screen)
	
	if initial_focus:
		initial_focus.grab_focus()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


# --- Screen Management ---

func hide_all_screens() -> void:
	for s in screens.values():
		s.hide()
		
func switch_to_screen(screen) -> void:
	if screen not in screens:
		push_error("{screen} not in screens")
		return
		
	if current_screen:
		if current_screen not in screens:
			push_error("{current_screen} not in screens")
			return
		screens[current_screen].hide()
	
	screens[screen].show()
	
	current_screen = screen
	

# --- Title Screen ---
	
func _on_play_btn_pressed() -> void:
	switch_to_screen("play")
	$PlayScreen/PanelContainer/VBoxContainer/VBoxContainer/PlayNormalBtn.grab_focus()
	
func _on_settings_btn_pressed() -> void:
	pass # Replace with function body.

func _on_highscore_pressed() -> void:
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	pass


# --- Play Screen ---

func _on_play_easy_btn_pressed() -> void:
	play.emit(GameSettings.easy())

func _on_play_normal_btn_pressed() -> void:
	play.emit(GameSettings.normal())

func _on_play_hard_btn_pressed() -> void:
	play.emit(GameSettings.hard())

func _on_play_sinucidal_btn_pressed() -> void:
	play.emit(GameSettings.sinucidal())

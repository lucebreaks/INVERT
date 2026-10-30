extends Node3D

@export var game_scene_path : String = "res://test.tscn"

@onready var campaign_button: Button = $MarginContainer/VBoxContainer/CanvasLayer/campaign
@onready var league_button: Button = $MarginContainer/VBoxContainer/CanvasLayer/league
@onready var play_button: Button = $MarginContainer/VBoxContainer/CanvasLayer/quickrace
@onready var multiplayer_button: Button = $MarginContainer/VBoxContainer/CanvasLayer/multiplayer
@onready var options_button: Button = $MarginContainer/VBoxContainer/CanvasLayer/options
@onready var quit_button: Button = $MarginContainer/VBoxContainer/CanvasLayer/quit

@onready var focus_sound_player: AudioStreamPlayer = %FocusSoundPlayer
@onready var submit_sound_player: AudioStreamPlayer = $SubmitSoundPlayer

func _ready() -> void:

	if campaign_button:
		campaign_button.focus_entered.connect(_on_button_focus_entered)
		campaign_button.mouse_entered.connect(play_button.grab_focus)
		campaign_button.pressed.connect(_on_quickrace_pressed)
	if league_button:
		league_button.focus_entered.connect(_on_button_focus_entered)
		league_button.mouse_entered.connect(play_button.grab_focus)
		league_button.pressed.connect(_on_quickrace_pressed)
	if play_button:
		play_button.focus_entered.connect(_on_button_focus_entered)
		play_button.mouse_entered.connect(play_button.grab_focus)
		play_button.pressed.connect(_on_quickrace_pressed)
	if multiplayer_button:
		multiplayer_button.focus_entered.connect(_on_button_focus_entered)
		multiplayer_button.mouse_entered.connect(play_button.grab_focus)
		multiplayer_button.pressed.connect(_on_quickrace_pressed)
	if options_button:
		options_button.focus_entered.connect(_on_button_focus_entered)
		options_button.mouse_entered.connect(play_button.grab_focus)
		options_button.pressed.connect(_on_quickrace_pressed)
	if quit_button:
		quit_button.focus_entered.connect(_on_button_focus_entered)
		quit_button.mouse_entered.connect(quit_button.grab_focus)
		quit_button.pressed.connect(_on_quit_pressed)

	if play_button:
		play_button.call_deferred("grab_focus")

func _process(_delta: float) -> void:
	if get_viewport().gui_get_focus_owner() == null and play_button:
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			play_button.grab_focus()

func _on_button_focus_entered() -> void:
	if is_inside_tree() and focus_sound_player and focus_sound_player.stream:
		focus_sound_player.play()

func _on_quickrace_pressed() -> void:
	if submit_sound_player and submit_sound_player.stream:
		submit_sound_player.play()
		await submit_sound_player.finished
	get_tree().change_scene_to_file(game_scene_path)

func _on_quit_pressed() -> void:
	if submit_sound_player and submit_sound_player.stream:
		submit_sound_player.play()
		await submit_sound_player.finished
	get_tree().quit()

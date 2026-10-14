extends Node3D
@onready var radio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var music_popup: Control = $CanvasLayer/MusicPopup

func _ready() -> void:
	# Make sure the UI node's visibility properties are correct

	# Connect the 3D player to the UI pop-up
	radio_player.track_started.connect(music_popup.show_track_popup)

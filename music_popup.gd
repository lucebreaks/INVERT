extends Control

@onready var label = $VBoxContainer/SongLabel 

var tween: Tween

func _ready() -> void:
	top_level = true 
	modulate.a = 0.0
	hide()

func show_track_popup(song_title: String) -> void:
	label.text = "Now Playing: " + song_title
	show()
	
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	# Wait for 3 seconds
	tween.tween_interval(3.0)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hide)

extends AudioStreamPlayer3D

signal track_started(song_title: String)

# Pair your audio resources with custom display titles in the Inspector
@export var playlist: Dictionary[AudioStream, String] = {}

func play_playlist_track(new_stream: AudioStream) -> void:
	stream = new_stream
	play()
	
	# Look up the track title from your dictionary map
	var display_title: String = playlist.get(stream, "Unknown Track")
	track_started.emit(display_title)

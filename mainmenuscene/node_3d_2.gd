extends Node3D

@export var rotation_speed: Vector3 = Vector3(0, 10, 0) # Degrees per second

func _process(delta: float) -> void:
	# Changed from rotation_deg to rotation_degrees
	rotation_degrees += rotation_speed * delta 

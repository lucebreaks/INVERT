extends Node3D

@onready var spawn_point = $"../SpawnPoint"

func respawn() -> void:
	global_position = spawn_point.global_position
	Vector2.ZERO

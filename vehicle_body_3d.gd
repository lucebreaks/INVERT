extends VehicleBody3D

@export var MAX_STEER = 0.9
@export var ENGINE_POWER = 300

func _init_input_actions() -> void:
	var _actions := {
		"accelerate" = [KEY_UP,    KEY_W, KEY_I],
		"brake"      = [KEY_DOWN,  KEY_S, KEY_K],
		"turn_left"  = [KEY_LEFT,  KEY_A, KEY_J],
		"turn_right" = [KEY_RIGHT, KEY_D, KEY_L],
			}

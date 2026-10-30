extends Node

var VintekPlayerSelection: bool = false
var BulletPlayerSelection: bool = false

func match_player_vehicle(carname: String) -> void:
	match carname:
		"Warlander": VintekPlayerSelection = true
		"Bullet": VintekPlayerSelection = true

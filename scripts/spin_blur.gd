extends SpinBlur

func _set_activation_speed_threshold_lower(value: float) -> void:
	value = max(0, value)
	activation_speed_threshold_lower = value
	
	if _activation_threshold_setter_gate:
		return
	
	_activation_threshold_setter_gate = true
	
	activation_speed_threshold_upper = \
	max(activation_speed_threshold_upper, activation_speed_threshold_lower)
	
	_activation_threshold_setter_gate = false


func _set_activation_speed_threshold_upper(value: float) -> void:
	value = max(0, value)
	activation_speed_threshold_upper = value
	
	if _activation_threshold_setter_gate:
		return
	
	_activation_threshold_setter_gate = true
	
	activation_speed_threshold_lower = \
	min(activation_speed_threshold_upper, activation_speed_threshold_lower)
	
	_activation_threshold_setter_gate = false

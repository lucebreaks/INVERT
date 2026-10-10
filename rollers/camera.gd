extends Camera3D

@export var min_fov: float = 75.0
@export var max_fov: float = 180.0
@export var min_speed: float = 0.0
@export var max_speed: float = 5.0
@export var lerp_speed: float = 10.0
@export var target: RigidBody3D    
@export var distance: float = 5.0 
@export var height: float = 2.0 
@export var follow_speed: float = 5.0  

func _physics_process(delta: float) -> void:
	if not target:
		return

	var car_forward = -target.global_transform.basis.z
	
	var target_pos = target.global_position - (car_forward * distance)
	target_pos.y += height

	global_position = global_position.lerp(target_pos, follow_speed * delta)

	look_at(target.global_position, Vector3.UP)

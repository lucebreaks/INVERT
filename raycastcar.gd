extends RigidBody3D

@export var shapecast : ShapeCast3D

@export var SPEEDOMETER_LABEL: Label
@export var wheels: Array[RaycastWheel]
@export var acceleration := -600.0
@export var max_speed := 20.0
@export var accel_curve : Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25

@export_group("Aerodynamics")
@export var downforce_coefficient: float = 2.0 
@export var max_downforce: float = 1500.0 
@export var ground_downforce: float = 1500.0
@export_node_path("RigidBody3D") var wheels_parent_path

@onready var wheels_parent = get_node(wheels_parent_path)

@onready var engine_sound: AudioStreamPlayer3D = $EngineSound

@export var min_pitch: float = 0.6
@export var max_pitch: float = 20.0


var motor_input := 0


func _ready() -> void:
	if shapecast:
		shapecast.add_exception(get_parent())
		
	

	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("gas"):
		motor_input = 1
	elif event.is_action_released("gas"):
		motor_input = 0
		
	if event.is_action_pressed("brake"):
		motor_input = -1
	elif event.is_action_released("brake"):
		motor_input = 0
		

func _basic_steering_rotation(delta: float) -> void:
	var turn_input := Input.get_axis("right", "left") * tire_turn_speed
	
	if turn_input:
		$wheelFL.rotation.y = clampf($wheelFL.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
		$wheelFR.rotation.y = clampf($wheelFR.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
	else:
		$wheelFL.rotation.y = move_toward($wheelFL.rotation.y, 0, tire_turn_speed * delta)
		$wheelFR.rotation.y = move_toward($wheelFR.rotation.y, 0, tire_turn_speed * delta)
		
		
func _physics_process(_delta: float) -> void:
	_basic_steering_rotation(_delta)
	for wheel in wheels:
		wheel.force_raycast_update()
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel)
		_do_single_wheel_tractions(wheel)
		
	if is_any_raycast_grounded():
		var down_vector = -global_transform.basis.y
		apply_central_force(down_vector * ground_downforce)
	else:
		pass


	if SPEEDOMETER_LABEL:
		SPEEDOMETER_LABEL.text = str(linear_velocity.length() * 3.9)

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
	
func _do_single_wheel_tractions(ray: RaycastWheel) -> void:
	if not ray.is_colliding(): return
	for wheel in wheels:
		wheel.force_raycast_update()
		
	var steer_side_dir := ray.global_basis.x
	var tire_vel := _get_point_velocity(ray.wheel.global_position)
	var steering_x_vel := steer_side_dir.dot(tire_vel)
	var x_traction := 1.0
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var x_force := -steer_side_dir * steering_x_vel * x_traction * ((mass*gravity)/4.0)
	
	var f_vel := -ray.global_basis.z.dot(tire_vel)
	var z_traction := 0.05
	var z_force := global_basis.z * f_vel * z_traction * ((mass*gravity)/4.0)
	
	
	var force_pos := ray.wheel.global_position - global_position
	apply_force(x_force, force_pos)
	apply_force(z_force, force_pos)

func _do_single_wheel_acceleration(ray: RaycastWheel) -> void:
	var forward_dir := -ray.global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	ray.wheel.rotate_x((-vel * get_process_delta_time())/ray.wheel_radius)
	
		
	if ray.is_colliding() and ray.is_motor:
		var speed_ratio := vel / max_speed
		var ac := accel_curve.sample_baked(speed_ratio)
		var contact := ray.get_collision_point()
		if shapecast:
			contact = shapecast.get_collision_point(0)
		var force_vector := forward_dir * acceleration * motor_input * ac
		var force_pos := contact - global_position
		
		if vel > max_speed:
			force_vector = force_vector * 0.1
			
		if motor_input:
			var projected_vector: Vector3 = (force_vector - ray.get_collision_normal() * force_vector.dot(ray.get_collision_normal())) 
			apply_force(force_vector, force_pos)
			
			
func _do_single_wheel_suspension(ray: RaycastWheel) -> void:
	if ray.is_colliding():
		var contact := ray.get_collision_point()
		var spring_up_dir := ray.global_transform.basis.y
		var spring_len := ray.global_position.distance_to(contact) - ray.wheel_radius
		var offset := ray.rest_dist - spring_len
		
		ray.wheel.position.y = -spring_len
		
		var spring_force := ray.spring_strength * offset
		
		var world_vel := _get_point_velocity(contact)
		var relative_vel := spring_up_dir.dot(world_vel)
		var spring_damp_force := ray.spring_damping * relative_vel
		
		var force_vector := (spring_force - spring_damp_force) * spring_up_dir
		
		contact = ray.wheel.global_position
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forward_speed: float = linear_velocity.length()

	if forward_speed > 1.0:
		var downforce_amount: float = downforce_coefficient * (forward_speed * forward_speed)
		downforce_amount = clamp(downforce_amount, 0.0, max_downforce)
		
		var local_down_vector: Vector3 = -global_transform.basis.y

		state.apply_central_force(local_down_vector * downforce_amount)

	if state.angular_velocity.length() > 0.1:
		state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, 2.0 * get_physics_process_delta_time())
		
func is_any_raycast_grounded() -> bool:
	if not wheels_parent:
		return false
		
	for child in wheels_parent.get_children():
		if child is RayCast3D:
			if child.is_colliding():
				return true 
				
	return false


func _process(delta: float) -> void:
	var current_speed = linear_velocity.length()
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	engine_sound.pitch_scale = lerp(min_pitch, max_pitch, speed_ratio)

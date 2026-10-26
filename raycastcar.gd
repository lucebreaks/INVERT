extends RigidBody3D

@export var shapecast : ShapeCast3D

@export var SPEEDOMETER_LABEL: Label
@export var wheels: Array[RaycastWheel]
@export var acceleration := -600.0
@export var reverse := 200.0
@export var max_speed := 20.0
@export var accel_curve : Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25
@onready var camera = $SpringArm3D/Camera # Adjust this path to match your Camera3D node
@export var max_speed_kmh: float = 300.0  # Speed where camera shake reaches maximum strength
@export var shake_threshold_kmh: float = 100.0 # Speed where camera shake starts appearing


@export var max_shake_amplitude: float = 0.2
@export var shake_speed: float = 30.0

var shake_timer: float = 0.0

@export_group("Aerodynamics")
@export var downforce_coefficient: float = 2.0 
@export var max_downforce: float = 1500.0 
@export var ground_downforce: float = 1500.0
@export_node_path("RigidBody3D") var wheels_parent_path

@onready var wheels_parent = get_node(wheels_parent_path)

@export_group("SFX")
@onready var engine_sound: AudioStreamPlayer3D = $EngineSound
@export var min_pitch: float = 0.6
@export var max_pitch: float = 20.0
@onready var jet_sound: AudioStreamPlayer3D = $JetSound
@export var jet_min_pitch: float = 0.6
@export var jet_max_pitch: float = 20.0
@export var min_vol_jet: float = -80
@export var max_vol_jet: float = -50

@export_group("flipping")
@export var orientation: int = 1
@export var up_ray: RayCast3D
@export var down_ray: RayCast3D

@export_group("handbrake")
var motor_input := 0
var hand_break := false

func _ready() -> void:
	if shapecast:
		shapecast.add_exception(get_parent())
		
	

	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("handbreak"):
		hand_break = true
	elif event.is_action_released("handbreak"):
		hand_break = false
		
	if event.is_action_pressed("gas"):
		motor_input = 1
	elif event.is_action_released("gas"):
		motor_input = 0
		
	if event.is_action_pressed("brake"):
		motor_input = -1
	elif event.is_action_released("brake"):
		motor_input = 0
		

func _basic_steering_rotation(delta: float) -> void:
	var turn_input := Input.get_axis("right", "left") * tire_turn_speed * orientation ##ADDED ORIENTATION HERE
	
	if turn_input:
		$wheelFL.rotation.y = clampf($wheelFL.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
		$wheelFR.rotation.y = clampf($wheelFR.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
	else:
		$wheelFL.rotation.y = move_toward($wheelFL.rotation.y, 0, tire_turn_speed * delta)
		$wheelFR.rotation.y = move_toward($wheelFR.rotation.y, 0, tire_turn_speed * delta)
		
		
func _physics_process(_delta: float) -> void:
	#TREK WUZ HERE!!!!!!!!
	#Sets orientation based on up/down rays.
	#Force them to update, probabuly unnescessary but whatever.
	up_ray.force_raycast_update()
	down_ray.force_raycast_update()
	var downDist = 100.0 #Initialize distances at total length (adjust if needed for >100m distances)
	var upDist = 100.0
	if down_ray.is_colliding():
		downDist = global_position.distance_to(down_ray.get_collision_point())
	if up_ray.is_colliding():
		upDist = global_position.distance_to(up_ray.get_collision_point())
	
	#uses two if statements instead of just an else because if they're the same then don't bother adjusting orientation.
	if upDist < downDist:
		orientation = -1
	elif downDist < upDist:
		orientation = 1
		
	
	_basic_steering_rotation(_delta)
	for wheel in wheels:
		if orientation > 0:
			wheel.target_position = Vector3.DOWN*1.835
		elif orientation < 0:
			wheel.target_position = Vector3.UP*1.835
		wheel.force_raycast_update()
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel)
		_do_single_wheel_tractions(wheel)

	if is_any_raycast_grounded():
		var down_vector = -global_transform.basis.y
		apply_central_force(down_vector * ground_downforce*orientation) ##ADDED ORIENTATION HERE
	else:
		pass
#flipping handling

#speedometer setup
	var raw_speed = linear_velocity.length()
	var display_speed = raw_speed * 3.6 
	if SPEEDOMETER_LABEL:
		SPEEDOMETER_LABEL.text = "%.0f" % display_speed
		
	var current_speed_kmh = raw_speed * 3.6
	#Camera Shake
	apply_high_speed_shake(current_speed_kmh, _delta)

func apply_high_speed_shake(current_speed: float, delta: float) -> void:
	if not camera:
		return
		
	if current_speed < shake_threshold_kmh:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
		
	var speed_range = max_speed_kmh - shake_threshold_kmh
	var speed_factor = (current_speed - shake_threshold_kmh) / speed_range
	speed_factor = clamp(speed_factor, 0.0, 1.0) # Keep it strictly between 0 and 1

	shake_timer += delta * shake_speed
	
	var shake_x = sin(shake_timer) * max_shake_amplitude * speed_factor
	var shake_y = cos(shake_timer * 1.5) * max_shake_amplitude * speed_factor
	
	camera.h_offset = shake_x
	camera.v_offset = shake_y
	
	
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
	
	if hand_break:
		x_traction = 0.1
		 
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
	ray.wheel.rotate_x((-vel * get_process_delta_time()) * 0.5 * PI * ray.wheel_radius)
	
		
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
		var spring_up_dir := ray.global_transform.basis.y*orientation ##ORIENTATION ADDED HERE
		var spring_len := ray.global_position.distance_to(contact) - ray.wheel_radius
		var offset := ray.rest_dist - spring_len
		
		ray.wheel.position.y = -spring_len*orientation ##ORIENTATION ADDED HERE
		
		var spring_force := ray.spring_strength * offset
		
		var world_vel := _get_point_velocity(contact)
		var relative_vel := spring_up_dir.dot(world_vel)
		var spring_damp_force := ray.spring_damping * relative_vel
		
		var force_vector := (spring_force - spring_damp_force) * spring_up_dir
		#force_vector += Vector3.DOWN*get_gravity()*100
		
		contact = ray.wheel.global_position
		var force_pos_offset := contact - global_position
		if not Input.is_action_pressed("ui_accept"):
			apply_force(force_vector, force_pos_offset)
		#DebugDraw3D.draw_line(global_position+force_pos_offset,global_position+force_pos_offset+(force_vector*0.1),Color.RED)

		ray.wheel.position.y = -spring_len*orientation
		

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forward_speed: float = linear_velocity.length()

	if forward_speed > 1.0:
		var downforce_amount: float = downforce_coefficient * (forward_speed * forward_speed)
		downforce_amount = clamp(downforce_amount, 0.0, max_downforce)
		#print(downforce_amount)
		
		var local_down_vector: Vector3 = -global_transform.basis.y * orientation ##ORIENTATION ADDED HERE

		state.apply_central_force(local_down_vector * downforce_amount)

	if state.angular_velocity.length() > 0.1:
		state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, 2.0 * get_physics_process_delta_time())
		
#flipped handling setup




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
	jet_sound.pitch_scale = lerp(jet_min_pitch, jet_max_pitch, speed_ratio)
	jet_sound.volume_db = lerp(min_vol_jet, max_vol_jet, current_speed*0.015)

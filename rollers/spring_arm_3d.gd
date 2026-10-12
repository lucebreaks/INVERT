extends SpringArm3D

@export var target_node: Node3D        # Drag your Car node here
@export var follow_speed: float = 6.0   
@export var rotation_speed: float = 4.0 

@export_group("Height Stability")
@export var fixed_height_offset: float = 1.8 
@export var height_smooth_speed: float = 8.0 

@export_group("Dynamic FOV")
@export var camera_node: Camera3D      
@export var min_fov: float = 90.0      
@export var max_fov: float = 120.0     
@export var max_speed: float = 10.0    
@export var fov_change_speed: float = 5.0 

var noise: FastNoiseLite = FastNoiseLite.new()
var noise_time: float = 0.0
var original_collision_mask: int = 1
var target_global_height: float = 0.0

func _ready() -> void:
	top_level = true
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	original_collision_mask = collision_mask
	
	if not camera_node:
		camera_node = get_child(0) as Camera3D
		
	if target_node:
		global_position = target_node.global_position
		target_global_height = target_node.global_position.y + fixed_height_offset
		_snap_to_target_orientation()
		
		# DEEP EXCLUSION: Recursively find and ignore all colliders on the vehicle
		_exclude_all_vehicle_colliders(target_node)
		
		# Also ignore the parent if the target node is a child marker on the car
		if target_node.get_parent():
			_exclude_all_vehicle_colliders(target_node.get_parent())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_node):
		return

	# 1. Height Stability Calculations
	var next_x: float = lerp(global_position.x, target_node.global_position.x, follow_speed * delta)
	var next_z: float = lerp(global_position.z, target_node.global_position.z, follow_speed * delta)
	var desired_height: float = target_node.global_position.y + fixed_height_offset
	target_global_height = lerp(target_global_height, desired_height, height_smooth_speed * delta)
	global_position = Vector3(next_x, target_global_height, next_z)

	# 2. Dynamic Flip Mask Bypass
	var car_up_vector: Vector3 = target_node.global_transform.basis.y
	if car_up_vector.y < 0.0:
		collision_mask = 0 
	else:
		collision_mask = original_collision_mask

	# 3. Flat Rotation Mathematics
	var car_forward: Vector3 = -target_node.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(car_forward.x, 0.0, car_forward.z).normalized()
	
	if flat_forward.length_squared() < 0.001:
		flat_forward = -global_transform.basis.z 

	var target_basis: Basis = Basis.looking_at(flat_forward, Vector3.UP)
	var target_rotation: Quaternion = target_basis.get_rotation_quaternion()
	var current_rotation: Quaternion = global_transform.basis.get_rotation_quaternion()
	var next_rotation: Quaternion = current_rotation.slerp(target_rotation, rotation_speed * delta)
	global_transform.basis = Basis(next_rotation)

	# 4. Secondary Speed FX (FOV/Shake)
	var current_speed: float = 0.0
	if "linear_velocity" in target_node:
		current_speed = target_node.linear_velocity.length()
	elif "velocity" in target_node:
		current_speed = target_node.velocity.length()

	if camera_node:
		var speed_ratio: float = clamp(remap(current_speed, 0.0, max_speed, 0.0, 1.0), 0.0, 1.0)
		var desired_fov: float = lerp(min_fov, max_fov, speed_ratio)
		camera_node.fov = lerp(camera_node.fov, desired_fov, fov_change_speed * delta)

# Traverses the car node tree and forces SpringArm3D to ignore every single physics object it encounters
func _exclude_all_vehicle_colliders(root_node: Node) -> void:
	if root_node.has_method("get_rid"):
		var rid = root_node.get_rid()
		if rid.is_valid():
			add_excluded_object(rid)
			
	# Recursively loop through all children, grandchildren, etc.
	for child in root_node.get_children():
		_exclude_all_vehicle_colliders(child)

func _snap_to_target_orientation() -> void:
	var car_forward: Vector3 = -target_node.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(car_forward.x, 0.0, car_forward.z).normalized()
	if flat_forward.length_squared() > 0.001:
		global_transform.basis = Basis.looking_at(flat_forward, Vector3.UP)

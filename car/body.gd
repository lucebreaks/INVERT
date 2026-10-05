extends VehicleBody3D

@export var MAX_STEER = 0.4
@export var ENGINE_POWER = 1800
@export var SPEEDOMETER_LABEL: Label

@onready var front_left_wheel: VehicleWheel3D = $front2
@onready var front_right_wheel: VehicleWheel3D = $front1
@onready var back_left_wheel: VehicleWheel3D = $back2
@onready var back_right_wheel: VehicleWheel3D = $back1

@onready var fl_mesh: Node3D = $front2/ROLLERFRONTWHEEL
@onready var fr_mesh: Node3D = $front1/ROLLERFRONTWHEEL
@onready var bl_mesh: Node3D = $back2/ROLLERFRONTWHEEL
@onready var br_mesh: Node3D = $back1/ROLLERFRONTWHEEL

@export_group("Center of Mass Balance")
@export var upright_center_of_mass_y: float = -1.6 
@export var inverted_center_of_mass_y: float = 1.6

@export_group("Aerodynamics")
@export var downforce_coefficient: float = 2.0 
@export var max_downforce: float = 1500.0 


var wheels_list: Array[VehicleWheel3D] = []
var meshes_list: Array[Node3D] = []
var normal_wheel_height: float = 0.0 
var is_upside_down: bool = true

var buttcast = true
var headcast = false

func _ready() -> void:
	wheels_list = [front_left_wheel, front_right_wheel, back_left_wheel, back_right_wheel]
	meshes_list = [fl_mesh, fr_mesh, bl_mesh, br_mesh]
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, upright_center_of_mass_y, 0.0)
	
	if is_instance_valid(front_left_wheel):
		normal_wheel_height = front_left_wheel.position.y
		
func _physics_process(delta: float) -> void:
	if buttcast == true:
		steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
		
	if headcast == true:
		steering = move_toward(steering, -Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	engine_force = Input.get_axis("brake", "gas") * ENGINE_POWER

	is_upside_down = global_transform.basis.y.y < 0.0
	
	var throttle_input: float = Input.get_axis("brake", "gas") 
	var steering_input: float = Input.get_axis("right", "left") 
	
	if is_upside_down:
		steering_input *= -1.0
		
	if SPEEDOMETER_LABEL:
		SPEEDOMETER_LABEL.text = str(linear_velocity.length() * 3.9)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forward_speed: float = linear_velocity.length()

	if forward_speed > 1.0:
		var downforce_amount: float = downforce_coefficient * (forward_speed * forward_speed)
		downforce_amount = clamp(downforce_amount, 0.0, max_downforce)
		
		var local_down_vector: Vector3 = -global_transform.basis.y

		state.apply_central_force(local_down_vector * downforce_amount)

	if state.angular_velocity.length() > 0.1:
		# Gently decelerate rotational glitching back down to sanity
		state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, 2.0 * get_physics_process_delta_time())

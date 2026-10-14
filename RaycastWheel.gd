extends RayCast3D
class_name RaycastWheel


@export var spring_strength := 5000.0
@export var spring_damping := 100
@export var rest_dist := 0.0
@export var wheel_radius := 1.5
@export var is_motor := false
@export var grip_curve : Curve
@onready var wheel: Node3D = get_child(0)

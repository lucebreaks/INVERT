@tool
class_name SpinBlur
extends Node3D

const ENVELOPING_MESH_FRONT_SHADER: Shader = preload("res://addons/easy_3d_spin_blur/spin_blur_mesh_front.gdshader")

const DEBUG_SHADER: Shader = preload("res://addons/easy_3d_spin_blur/debug_spin_mesh.gdshader")

const SPIN_BLUR_ROOT_META_KEY: StringName = &"spin_blur_root"

const ENVELOPING_NODE_META_KEY: StringName = &"spin_blur_enveloping_node"

const SHADOW_DUP_INTERMEDIARY: StringName = &"spin_blur_shadow_dup_intermediary"

const SHADOW_DUP_META_KEY: StringName = &"spin_blur_shadow_dup"


@export var target: Node3D:
	set = _set_target

@export var enabled := true:
	set = _set_enabled

## A render layer reserved for the spin blur to do its thing. Multiple spin
## blurs can use the same render layer, with a slight caveat that if their targets
## overlap it can results in some artifacts.
## The value range is 3 - 20. Setting it to 1 would clash with the default render
## layer, and setting it to 2 would break gizmos in the editor.
@export_range(3, 20, 1) var reserved_render_layer: int = 3:
	set = _set_layer

## When disabling/removing the spin blur, it will revent the render layers of
## [member target] to this value
@export_flags_3d_render var layers_to_revert = 1

## A rotation axis local to [member target] along which spin blur will occur
@export var target_rotation_axis: Vector3 = Vector3(1, 0, 0)

## When [code]ture[/code], the rotation axis will not be determined by [member target_rotation_axis].
## Instead it will be determined by the angular difference of the mesh between frames. This means the
## enveloping mesh and the spin blur would align to the current rotation axis of your mesh, regardless
## to it's orientation. To compare, the default behavior sticks to target_rotation_axis local to the target
## mesh, and extract how much of the mesh's actual rotation aligns with that axis.
## A usecase of this feature is for uniform, free-rolling meshes like rolling balls.
@export var use_free_rotation_axis: bool = false

@export_subgroup("activation speed thresholds", "activation_speed_threshold")

## Above this rotation speed (in radians per frame), the spin blur will start
## fading in.
@export var activation_speed_threshold_lower: float = 0.0:
	set = _set_activation_speed_threshold_lower

## Above this rotation speed (in radians per frame), the spin blur will be fully
## faded in, and the target mesh will be turned invisible.
@export var activation_speed_threshold_upper: float = 0.0:
	set = _set_activation_speed_threshold_upper

var _activation_threshold_setter_gate := false

## Amount of motion blur samples. Higher values result in higher quality and smoothness
## at the cost of performance.
@export_range(1, 32, 1, "or_greater") var sample_count := 8

## Higher values mean grater blur angle for the same rotation speed. At 1.0
## the blur would span the rotation step fully, at 0.5, only half the rotation
## step would be blurred along, and so on. 
@export_range(0.0, 1.0, 0.001, "or_greater") var blur_intensity: float = 1.0

## The higher the value, the more pronounced the rolling shutter effect. Works independently
## from [member blur_intensity], i.e. you can have rolling shutter without blur if you want.
## Applied in terms of rotation_speed * screen_height_fraction_offset * rolling_shutter_amount.
@export var rolling_shutter_amount: float = 0.0

@export_subgroup("lighting", "lighting_")

## When [code]true[/code], [method capture_lighting] will be invoked automatically when
## this spin blur is ready.
@export var lighting_capture_on_ready: bool = false

@export_tool_button("Capture Lighting") var lighting_capture = capture_lighting

@export_subgroup("shadows", "shadows_")

## When [code]true[/code], [method capture_shadows] will be invoked automatically when
## this spin blur is ready
@export var shadows_capture_on_ready: bool = false

@export_tool_button("Capture Shadows Editor Only") var shadows_capture = capture_shadows

## The enveloping mesh is what makes the spin blur possible. It is a mesh that tightly
## encapsulates the space the target mesh sweeps through as it rotates. You can generate
## it automatically after setting [member target_rotation_axis] by pressing [member generate_enveloping_mesh]
## tool button.
@export var enveloping_mesh: Mesh:
	set = _set_enveloping_mesh

@export_group("enveloping mesh generation")

## When generating the enveloping mesh, defines how many rings of vertices
## to use. Higher values mean higher details
@export var rings: int = 16

## How many radial segments to generate the mesh with. Higher value means
## more circular mesh.
@export var radial_segments: int = 32

## The mesh generation is not perfect, it's based on a polar vertex profile, which disregards faces
## and edges. If you have a very simple mesh with large faces that the rotation axis goes through,
## the generated mesh may end up with a hole in its center. If you have a mesh with an intentional
## hole in its center, set this variable to [code]false[/code]
@export var fill_center: bool = true

## The mesh generation captures all mesh instances that are children of the target node,
## and generates separate mesh surfaces for each by default. Setting this to [code]true[/code]
## will generate a single surface to envelop all meshes.
@export var unify_meshes: bool = true

## Add padding to the generated mesh in perpendicular to the rotation axis (make it wider)
@export var radial_padding: float = 0

## Add padding to the generated mesh along the rotation axis 
@export var depth_padding: float = 0

## When pressed, generates an enveloping mesh for the target mesh based on it and the
## axis set in [member target_rotation_axis].
@export_tool_button("generate enveloping mesh") var generate_enveloping_mesh = _generate_enveloping_mesh

@export_group("debug")

## Allows you to simulate the behavior of the blur in the editor at different rotation speeds.
## This would not actually rotate the mesh, just show you what the blur would look like if it did.
@export var override_rotation_speed := 0.0

## A color to display the enveloping mesh wireframe with.
@export var debug_color: Color = Color("ffffff0a")

## Whether to show the enveloping mesh in the editor.
@export var draw_debug := true

var _viewport: SubViewport:
	set = _set_viewport

var _camera: SpinBlurCamera:
	set = _set_camera

# Whether the spin blur is truly enabled. It is determined based
# on whether it is ready, whether it has a target, and whether [mermber enabled] is true
var _enabled: bool = false:
	set(value):
		if _enabled == value:
			return
		
		_enabled = value
		
		if _enabled:
			_enable()
			
		else:
			_disable()

var _layer_mask: int = 1 << (reserved_render_layer - 1)

var _enveloping_node: MeshInstance3D

var _past_global_transform: Transform3D

var _debug_material: ShaderMaterial

var _rotation_vector_cache: Vector3

var _rotation_speed_cache: float

var _fade_in_coef_cache: float


func _enter_tree() -> void:
	SpinBlurHelpers.register_spin_blur(self)
	
	_update_enabled()
	
	# Since we are setting the depth texture uniform to null when exiting the tree,
	# we have to recover it upon entering again, indicated by the node being ready at this point.
	if is_node_ready():
		_update_depth_texture()


func _exit_tree() -> void:
	SpinBlurHelpers.unregister_spin_blur(self)
	
	_enabled = false
	
	# This fixes a rendering device error regarding invalid bindings
	# when the spin blur node is deleted in the editor, and perhaps other scenarios
	_set_shader_parameter_recursive(
		_enveloping_node.material_override, 
		"depth_texture",
		null
	)


func _ready() -> void:
	for child in get_children():
		if child.has_meta(ENVELOPING_NODE_META_KEY):
			child.queue_free()
	
	_enveloping_node = MeshInstance3D.new()
	
	_enveloping_node.set_meta(ENVELOPING_NODE_META_KEY, true)
	
	var front_material := ShaderMaterial.new()
	
	front_material.shader = ENVELOPING_MESH_FRONT_SHADER
	
	front_material.render_priority = 1
	
	if Engine.is_editor_hint():
		_debug_material = ShaderMaterial.new()
		_debug_material.shader = DEBUG_SHADER
		_debug_material.render_priority = 3
		
		front_material.next_pass = _debug_material
	
	_enveloping_node.material_override = front_material
	
	add_child(_enveloping_node)
	
	# So that the viewport's view does not lag a frame behind the reference camera
	process_priority = 1
	
	_update_viewport_texture()
	_update_depth_texture()
	_update_enveloping_mesh()
	_update_enabled()
	
	if !Engine.is_editor_hint():
		if lighting_capture_on_ready:
			capture_lighting.call_deferred()
		
		if shadows_capture_on_ready:
			capture_shadows.call_deferred()


func _process(delta: float) -> void:
	if !_enabled:
		return
	
	if target_rotation_axis.is_zero_approx():
		return
	
	_update_enveloping_node()


static func _find_spin_blur(node: Node) -> SpinBlur:
	while node:
		var spin_blur: SpinBlur = _get_target_spin_blur(node)
		
		if spin_blur:
			return spin_blur
		
		node = node.get_parent()
	
	return null


static func _get_target_spin_blur(node: Node) -> SpinBlur:
	if !node.has_meta(SPIN_BLUR_ROOT_META_KEY):
		return null
	
	var spin_blur_instance_id: int = node.get_meta(SPIN_BLUR_ROOT_META_KEY)
	
	if !is_instance_id_valid(spin_blur_instance_id):
		return null
	
	var spin_blur: Variant = instance_from_id(spin_blur_instance_id)
	
	if spin_blur is not SpinBlur:
		return null
	
	if spin_blur.target != node:
		return null
	
	return spin_blur


## Detects lighting-related nodes and ensure they are visible under
## [member reserved_render_layer] render layer.
func capture_lighting() -> void:
	var lights_to_copy: Array[Node]
	
	_scan_for_lighting(get_viewport(), lights_to_copy)
	
	for light: Node in lights_to_copy:
		light.layers |= _layer_mask


## Detects all meshes that cast shadows in the scene, and creates duplicates for
## each one as children of those meshes, with she shadow casting mode set to
## [constant GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY], and the layers
## set to include [member reserved_render_layer]. This allows the shadows
## in the scene to get casted onto the separately rendered spin blur meshes.
func capture_shadows() -> void:
	var shadows_to_copy: Array[Node]
	
	_scan_for_shadows(get_viewport(), shadows_to_copy)
	
	for mesh: GeometryInstance3D in shadows_to_copy:
		# An intermediary node is necessary, because CSG meshes seem to have unexpected render layer
		# behavior across direct hierarchy.
		var intermediary_node: Node3D
		
		var mesh_dup: GeometryInstance3D
		
		for child in mesh.get_children():
			if child.has_meta(SHADOW_DUP_INTERMEDIARY):
				intermediary_node = child
				break
		
		if !intermediary_node:
			intermediary_node = Node3D.new()
			
			intermediary_node.set_meta(SHADOW_DUP_INTERMEDIARY, true)
			
			mesh.add_child(intermediary_node)
		
		for child in intermediary_node.get_children():
			if child.has_meta(SHADOW_DUP_META_KEY):
				mesh_dup = child
			
			break
		
		if !mesh_dup:
			mesh_dup = mesh.duplicate(0)
			
			mesh_dup.owner = null
			
			mesh_dup.scene_file_path = ""
			
			for child in mesh_dup.get_children():
				mesh_dup.remove_child(child)
				child.queue_free()
			
			mesh_dup.set_script(null)
			
			mesh_dup.layers = 0
			
			mesh_dup.set_meta(SHADOW_DUP_META_KEY, true)
			
			intermediary_node.add_child(mesh_dup)
		
		intermediary_node.name = "SpinBlurShadowIntermediary"
		
		intermediary_node.transform = Transform3D()
		
		mesh_dup.name = mesh.name + "_SpinBlurShadowDuplicate"
		
		mesh_dup.transform = Transform3D()
		
		mesh_dup.layers |= _layer_mask
		
		mesh_dup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Allows achieving color correctness with environments that have accumulative color effects like
## tonemapping and adjustments, by creating a duplicate of the environment with those turned off.
## In case where the environment sits on a camera, this can also be used to transfer that environment
## correctly to the spin blur.
## If the original environment changes, you may want to call this again.
## Note that this will affect all other spin blurs that share the same
## parent viewport and render layer.
func fix_environment(environment_node: Node) -> void:
	if environment_node is not WorldEnvironment and environment_node is not Camera3D:
		push_error("fix_environment() can only accept a WorldEnvironment or Camera3D nodes")
		return
	
	var environment: Environment = environment_node.environment.duplicate()
	
	environment.adjustment_enabled = false
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.0
	
	SpinBlurHelpers.set_spin_blur_custom_environment(self, environment)


func _enable() -> void:
	_target_set_layers_recursive(layers_to_revert | _layer_mask)


func _disable() -> void:
	_target_set_layers_recursive(layers_to_revert)
	visible = false


func _scan_for_lighting(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if _should_stop_recursion(child):
			continue
		
		if child is Light3D:
			result.append(child)
		
		_scan_for_lighting(child, result)


func _scan_for_shadows(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if _should_stop_recursion(child):
			continue
		
		if child is GeometryInstance3D:
			if child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED \
			or child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				result.append(child)
		
		_scan_for_shadows(child, result)


func _set_shader_parameter_recursive(
	material: ShaderMaterial, 
	parameter: String, 
	value: Variant
) -> void:
	if material.next_pass and material.next_pass is ShaderMaterial:
		_set_shader_parameter_recursive(material.next_pass, parameter, value)
	
	material.set_shader_parameter(parameter, value)


func _generate_enveloping_mesh() -> void:
	if !target:
		push_error("invalid target")
		return
	
	if target_rotation_axis.is_zero_approx():
		push_error("invalid rotation axis")
		return
	
	enveloping_mesh = SpinMesh.generate(
		_collect_target_meshes_recursive(), 
		target_rotation_axis, 
		rings, 
		radial_segments, 
		fill_center,
		unify_meshes,
		radial_padding, 
		depth_padding,
	)


func _collect_target_meshes_recursive(
	root: Node3D = target,
	node: Node = root, 
	ret: Dictionary[MeshInstance3D, Transform3D] = {}
) -> Dictionary[MeshInstance3D, Transform3D]:
	if node is MeshInstance3D and node.mesh and !_is_shadow_mesh(node):
		ret[node as MeshInstance3D] = root.global_transform.affine_inverse() * node.global_transform
	
	for child in node.get_children():
		if _should_stop_recursion(child):
			continue
		
		_collect_target_meshes_recursive(root, child, ret)
	
	return ret


func _target_set_layers_recursive(layers: int, node: Node = target) -> void:
	if !target:
		return
	
	if node is VisualInstance3D and !_is_shadow_mesh(node):
		node.layers = layers
	
	for child in node.get_children():
		if _should_stop_recursion(child):
			continue
		
		_target_set_layers_recursive(layers, child)


func _should_stop_recursion(node: Node) -> bool:
	if node is SpinBlur or node is SpinBlurShadow:
		return true
	
	if node is Viewport:
		return true
	
	if node.has_meta(SHADOW_DUP_INTERMEDIARY) \
	or node.has_meta(SHADOW_DUP_META_KEY) \
	or node.has_meta(ENVELOPING_NODE_META_KEY) \
	or node.has_meta(SpinBlurShadow.SHADOW_MESH_INSTANCE_META):
		return true
	
	if _get_target_spin_blur(node):
		return true
	
	return false


func _update_enabled() -> void:
	_enabled = is_node_ready() and enabled and target


func _update_enveloping_node() -> void:
	if Engine.is_editor_hint():
		_debug_material.set_shader_parameter(
			"color", 
			debug_color
		)
		
		_debug_material.set_shader_parameter(
			"enabled", 
			1 if draw_debug else 0
		)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"rolling_shutter_amount", 
		rolling_shutter_amount
	)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"sample_count", 
		sample_count
	)
	
	var target_transform : Transform3D = target.global_transform
	
	var difference_quat: Quaternion = Quaternion(target_transform.basis.get_rotation_quaternion() \
	* _past_global_transform.basis.get_rotation_quaternion().inverse())
	
	var normalized_target_rotation_axis: Vector3 = target_rotation_axis.normalized()
	
	if use_free_rotation_axis:
		_rotation_vector_cache = difference_quat.get_axis()
		if _rotation_vector_cache.is_zero_approx():
			_rotation_vector_cache = Vector3.RIGHT
		
	else:
		_rotation_vector_cache = target_transform.orthonormalized().basis * normalized_target_rotation_axis
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"local_rotation_axis",
		 normalized_target_rotation_axis
	)
	
	var centered_angle: float = difference_quat.get_angle() - PI
	
	var angle: float = (PI - abs(centered_angle)) * abs(_rotation_vector_cache.dot(difference_quat.get_axis()))
	
	if !Engine.is_editor_hint() and target.has_method("_get_spin_blur_rotation_speed"):
		angle = target._get_spin_blur_rotation_speed() * get_process_delta_time()
	
	_rotation_speed_cache = angle \
	if override_rotation_speed == 0.0 or !Engine.is_editor_hint() \
	else override_rotation_speed
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"rotation_speed", 
		_rotation_speed_cache
	)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"blur_intensity", 
		blur_intensity,
	)
	
	var abs_rotation_speed: float = abs(_rotation_speed_cache)
	
	
	
	if abs_rotation_speed > activation_speed_threshold_upper:
		_target_set_layers_recursive(_layer_mask)
		
	else:
		_target_set_layers_recursive(layers_to_revert | _layer_mask)
	
	if abs_rotation_speed > activation_speed_threshold_lower or (draw_debug and Engine.is_editor_hint()):
		visible = true
		
	else:
		visible = false
	
	if activation_speed_threshold_upper == activation_speed_threshold_lower:
		_fade_in_coef_cache = 1.0 if abs_rotation_speed > activation_speed_threshold_lower else 0.0
		
	else:
		_fade_in_coef_cache = clamp(
			(abs_rotation_speed - activation_speed_threshold_lower) / (activation_speed_threshold_upper - activation_speed_threshold_lower), 
			0, 
			1
		)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"fade_in", 
		_fade_in_coef_cache
	)
	
	_past_global_transform = target_transform
	
	_enveloping_node.global_position = target_transform.origin
	
	var alignment_quaternion : Quaternion = \
	Quaternion(_enveloping_node.global_basis.orthonormalized() \
	* normalized_target_rotation_axis, _rotation_vector_cache)
	
	_enveloping_node.global_basis = \
	Basis(alignment_quaternion) * _enveloping_node.global_basis;
	
	_enveloping_node.global_basis.x = \
	_enveloping_node.global_basis.x.normalized() * target_transform.basis.x.length()
	
	_enveloping_node.global_basis.y = \
	_enveloping_node.global_basis.y.normalized() * target_transform.basis.y.length()
	
	_enveloping_node.global_basis.z = \
	_enveloping_node.global_basis.z.normalized() * target_transform.basis.z.length()


func _update_viewport_texture() -> void:
	if !is_node_ready():
		return
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"screen_texture",
		_viewport.get_texture() if _viewport else null
	)


func _update_depth_texture() -> void:
	if !is_node_ready():
		return
	
	var texture: Texture2D = null
	
	if _camera:
		texture = _camera.compositor.compositor_effects[0].texture_2d_rd
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"depth_texture", 
		texture
	)


func _update_enveloping_mesh() -> void:
	if _enveloping_node:
		_enveloping_node.mesh = enveloping_mesh


func _is_shadow_mesh(node: Node) -> bool:
	return node is GeometryInstance3D and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _set_enabled(value: bool) -> void:
	enabled = value
	
	_update_enabled()


func _set_layer(value: int) -> void:
	if reserved_render_layer == value:
		return
	
	reserved_render_layer = value
	
	_layer_mask = 1 << (reserved_render_layer - 1)
	
	if is_inside_tree():
		SpinBlurHelpers.sync_spin_blur_layer(self)


func _set_target(value: Node3D) -> void:
	target = value
	
	if target:
		if !target.is_node_ready():
			target.ready.connect(target.set_meta.bind(SPIN_BLUR_ROOT_META_KEY, get_instance_id()), CONNECT_ONE_SHOT)
			
		else:
			target.set_meta(SPIN_BLUR_ROOT_META_KEY, get_instance_id())
	
	_update_enabled()
	
	update_configuration_warnings()


func _set_enveloping_mesh(value: Mesh) -> void:
	enveloping_mesh = value
	
	_update_enveloping_mesh()
	
	update_configuration_warnings()


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


func _set_viewport(value: SubViewport) -> void:
	_viewport = value
	
	_update_viewport_texture()


func _set_camera(value: SpinBlurCamera) -> void:
	if _camera:
		var old_signal: Signal = _camera.compositor.compositor_effects[0].texture_generated
		
		if old_signal.is_connected(_update_depth_texture):
			old_signal.disconnect(_update_depth_texture)
	
	_camera = value
	
	if _camera:
		var new_signal: Signal = _camera.compositor.compositor_effects[0].texture_generated
		
		if !new_signal.is_connected(_update_depth_texture):
			new_signal.connect(_update_depth_texture.unbind(1))
	
	_update_depth_texture()

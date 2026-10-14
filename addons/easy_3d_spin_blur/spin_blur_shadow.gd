@tool
class_name SpinBlurShadow
extends Node3D

const SHADOW_MESH_INSTANCE_META: StringName = &"spin_blur_shadow_mesh_instance"

@export_range(1, 256, 1, "or_greater") var subdivisions: int = 20:
	set(value):
		subdivisions = value
		refresh_state()

@export_flags_3d_render var render_layers: int = 1

var _spin_blur: SpinBlur

var _parent_mesh: GeometryInstance3D

var _mesh_instances: Array[GeometryInstance3D]


func _enter_tree() -> void:
	refresh_state.call_deferred()


func _exit_tree() -> void:
	clear_state()


func _get_configuration_warnings() -> PackedStringArray:
	if !_spin_blur:
		if get_parent() is not GeometryInstance3D:
			return ["spin blur shadow must be a child of a geometry instance"]
		
		if !SpinBlur._find_spin_blur(get_parent()):
			return ["spin blur shadow's parent must be a target or a child of a target of a spin blur"]
	
	return []


func _process(delta: float) -> void:
	_update_meshes()


func refresh_state() -> void:
	_clear_mesh_instances()
	
	process_priority = 2
	
	var parent: Node = get_parent()
	
	if parent is not GeometryInstance3D:
		return
	
	_spin_blur = SpinBlur._find_spin_blur(parent)
	
	if !_spin_blur:
		return
	
	_parent_mesh = parent
	
	# We get a sanitized duplicate of the parent mesh, instead of duplicating the parent mesh
	# directly with each [method _create_new_duplicate]. The reason being that these duplicates
	# are added as descendants of [member _parent_mesh], and since duplication copies the entire subtree,
	# it becomes an unnecessarily heavy opeartion that grows exponentially.
	var sanitized_duplicate: GeometryInstance3D = _get_sanitized_duplicate(_parent_mesh)
	
	for i in subdivisions:
		_mesh_instances.append(_create_new_duplicate(sanitized_duplicate))


func clear_state() -> void:
	_clear_mesh_instances()
	
	_spin_blur = null
	
	_parent_mesh = null


func _update_meshes() -> void:
	if !_spin_blur:
		return
	
	for mesh: GeometryInstance3D in _mesh_instances:
		mesh.layers = render_layers
		mesh.visible = false
	
	if !_spin_blur.enabled:
		return
	
	_mesh_instances[0].global_transform = _parent_mesh.global_transform
	
	var angle_interval: float = TAU / subdivisions
	
	var symmetry_mesh_count: int = \
	floor((min(abs(_spin_blur._rotation_speed_cache * _spin_blur.blur_intensity), TAU) / 2.0) / angle_interval)
	
	for i in symmetry_mesh_count:
		var angle: float = angle_interval * (i + 1)
		
		var new_mesh_1: GeometryInstance3D = _mesh_instances[i * 2 + 1]
		
		new_mesh_1.global_position = \
		(_parent_mesh.global_position - _spin_blur.target.global_position).rotated(_spin_blur._rotation_vector_cache, angle) \
		+ _spin_blur.target.global_position
		
		new_mesh_1.global_basis = _parent_mesh.global_basis.rotated(_spin_blur._rotation_vector_cache, angle)
		
		# If the subdivision count is even, the last subdivision symmetry pair is the opposing angle,
		# meaning 2 overlapping meshes, and an assumed extra mesh. We need to exit early in that case.
		if i * 2 + 2 >= subdivisions:
			continue
		
		var new_mesh_2: GeometryInstance3D = _mesh_instances[i * 2 + 2]
		
		new_mesh_2.global_position = \
		(_parent_mesh.global_position - _spin_blur.target.global_position).rotated(_spin_blur._rotation_vector_cache, -angle) \
		+ _spin_blur.target.global_position
		
		new_mesh_2.global_basis = _parent_mesh.global_basis.rotated(_spin_blur._rotation_vector_cache, -angle)
	
	# If the subdivision count is even, the last subdivision symmetry pair is the opposing angle,
	# meaning 2 overlapping meshes, and an assumed extra mesh. We need to clamp the mesh count in that case.
	var active_mesh_count: int = min(subdivisions, 1 + symmetry_mesh_count * 2) 
	
	var transparency: float = min(
		0.99, 
		1.0 - (_spin_blur._fade_in_coef_cache * (1.0 - _parent_mesh.transparency) / float(active_mesh_count))
	)
	
	for i in active_mesh_count:
		_mesh_instances[i].visible = true
		_mesh_instances[i].transparency = transparency


func _get_sanitized_duplicate(node: GeometryInstance3D) -> GeometryInstance3D:
	var new_duplicate: GeometryInstance3D = _parent_mesh.duplicate(0)
	
	new_duplicate.owner = null
	
	new_duplicate.scene_file_path = ""
	
	for child in new_duplicate.get_children():
		new_duplicate.remove_child(child)
		child.queue_free()
	
	new_duplicate.set_script(null)
	
	return new_duplicate


func _create_new_duplicate(sanitized_duplicate: GeometryInstance3D) -> MeshInstance3D:
	if !_parent_mesh:
		push_error("cannot create shadow mesh instance, missing parent mesh")
		return null
	
	var new_duplicate: GeometryInstance3D = sanitized_duplicate.duplicate(0)
	
	new_duplicate.layers = render_layers
	
	new_duplicate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	
	new_duplicate.set_meta(SHADOW_MESH_INSTANCE_META, true)
	
	add_child(new_duplicate)
	
	return new_duplicate


func _clear_mesh_instances() -> void:
	for child in get_children():
		if child.has_meta(SHADOW_MESH_INSTANCE_META):
			child.queue_free()
	
	_mesh_instances.clear()

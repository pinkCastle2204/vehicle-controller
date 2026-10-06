extends Camera3D

# --- Target & Offset Settings ---
@export_group("Target")
@export var target_path: NodePath
## Height above the car pivot to look at (e.g. car center/roof)
@export var target_height_offset: float = 1.2

# --- Distance & Zoom ---
@export_group("Distance & Zoom")
@export var min_distance: float = 4.0
@export var max_distance: float = 8.0
@export var default_distance: float = 6.0
@export var zoom_speed: float = 0.5

# --- Orbit & Sensitivity ---
@export_group("Controls & Sensitivity")
@export var invert_y: bool = true
@export var mouse_sensitivity: float = 0.003
@export var joystick_sensitivity: Vector2 = Vector2(2.8, 2.2)
@export var joystick_deadzone: float = 0.15
## Exponential curve for micro-aim precision near deadzone (1.0 = linear, 2.0 = smooth curve)
@export var stick_response_curve: float = 2.0
@export_range(-80.0, 0.0, 0.1, "radians_as_degrees") var min_pitch: float = deg_to_rad(-15.0)
@export_range(0.0, 85.0, 0.1, "radians_as_degrees") var max_pitch: float = deg_to_rad(65.0)

# --- Smoothing & Polish ---
@export_group("Smoothness")
## How fast the camera glides to the target position
@export var follow_smoothness: float = 8.0
## Velocity damping: higher values stop quicker, lower values create silky momentum
@export var rotation_friction: float = 10.0

# --- Collision / Occlusion ---
@export_group("Collision")
@export var clip_collision: bool = true
@export_flags_3d_physics var collision_mask: int = 1
@export var collision_margin: float = 0.2

# --- Internal State ---
var _target_node: Node3D
var _current_distance: float
var _target_distance: float

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(15.0)

# Angular velocities for fluid inertia
var _yaw_velocity: float = 0.0
var _pitch_velocity: float = 0.0

# Filter buffer to eliminate controller stick potentiometer flicker on X
var _smoothed_stick_x: float = 0.0


func _ready() -> void:
	# Decouple transform from the vehicle body to avoid roll/pitch jerky movements
	set_as_top_level(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not target_path.is_empty():
		_target_node = get_node(target_path) as Node3D
	else:
		_target_node = get_parent() as Node3D

	_target_distance = clamp(default_distance, min_distance, max_distance)
	_current_distance = _target_distance

	if is_instance_valid(_target_node):
		# Initialize yaw behind the vehicle's initial facing vector
		_yaw = _target_node.global_basis.get_euler().y
		global_position = _calculate_desired_position(_yaw, _pitch, _current_distance)
		look_at(_get_focal_point(), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse Orbit
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var pitch_factor: float = 1.0 if invert_y else -1.0
		_yaw_velocity -= event.relative.x * mouse_sensitivity * 60.0
		_pitch_velocity += event.relative.y * mouse_sensitivity * 60.0 * pitch_factor

	# Mouse Wheel Zoom
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_distance = clamp(_target_distance - zoom_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_distance = clamp(_target_distance + zoom_speed, min_distance, max_distance)

	# Toggle Mouse Capture
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target_node):
		return

	_handle_gamepad_input(delta)

	# 1. Integrate rotational momentum
	_yaw += _yaw_velocity * delta
	_pitch += _pitch_velocity * delta

	# Normalize yaw to avoid float precision jumps during extended gameplay
	_yaw = wrapf(_yaw, -PI, PI)

	# 2. Hard clamp pitch and kill remaining velocity on impact
	if _pitch < min_pitch:
		_pitch = min_pitch
		_pitch_velocity = 0.0
	elif _pitch > max_pitch:
		_pitch = max_pitch
		_pitch_velocity = 0.0

	# 3. Apply exponential decay to rotational velocity (natural glide)
	var damping: float = exp(-rotation_friction * delta)
	_yaw_velocity *= damping
	_pitch_velocity *= damping

	# 4. Smooth zoom & positional tracking
	var pos_factor: float = 1.0 - exp(-follow_smoothness * delta)
	_current_distance = lerp(_current_distance, _target_distance, pos_factor)

	var focal_point := _get_focal_point()
	var desired_pos := _calculate_desired_position(_yaw, _pitch, _current_distance)

	# Prevent camera from clipping through geometry
	if clip_collision:
		desired_pos = _resolve_collision(focal_point, desired_pos)

	global_position = global_position.lerp(desired_pos, pos_factor)

	# Aim at focal point, guarded against zero-vector singularity
	if global_position.distance_squared_to(focal_point) > 0.001:
		look_at(focal_point, Vector3.UP)


func _handle_gamepad_input(delta: float) -> void:
	# Read the right stick directly from hardware device 0
	var raw_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var raw_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_input := Vector2(raw_x, raw_y)
	var stick_length: float = stick_input.length()

	var target_x: float = 0.0
	var target_y: float = 0.0

	if stick_length > joystick_deadzone:
		# Radial deadzone rescaling
		var remapped_mag: float = (stick_length - joystick_deadzone) / (1.0 - joystick_deadzone)
		remapped_mag = clamp(remapped_mag, 0.0, 1.0)
		remapped_mag = pow(remapped_mag, stick_response_curve)

		var dir: Vector2 = stick_input / stick_length
		target_x = dir.x * remapped_mag
		target_y = dir.y * remapped_mag

	# Low-pass filter to smooth potentiometer noise and eradicate horizontal jitter
	_smoothed_stick_x = lerp(_smoothed_stick_x, target_x, 1.0 - exp(-25.0 * delta))

	var pitch_factor: float = 1.0 if invert_y else -1.0

	_yaw_velocity -= _smoothed_stick_x * joystick_sensitivity.x * 12.0
	_pitch_velocity += target_y * joystick_sensitivity.y * 10.0 * pitch_factor


func _get_focal_point() -> Vector3:
	return _target_node.global_position + Vector3(0.0, target_height_offset, 0.0)


func _calculate_desired_position(p_yaw: float, p_pitch: float, p_dist: float) -> Vector3:
	var offset := Vector3(
		sin(p_yaw) * cos(p_pitch),
		sin(p_pitch),
		cos(p_yaw) * cos(p_pitch)
	) * p_dist

	return _get_focal_point() + offset


func _resolve_collision(from: Vector3, to: Vector3) -> Vector3:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)

	var exclude_rids: Array[RID] = []
	if _target_node is CollisionObject3D:
		exclude_rids.append((_target_node as CollisionObject3D).get_rid())
	query.exclude = exclude_rids

	var result := space_state.intersect_ray(query)
	if result:
		return result.position + result.normal * collision_margin

	return to

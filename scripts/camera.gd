extends Camera3D
## GTA V / Need for Speed style vehicle chase camera.
## Attach to a Camera3D that is a child of (or points at) your RigidBody3D car.
## Car forward is assumed to be -Z (same as your wheel script).

# ───────────────────────── Target ─────────────────────────
@export_group("Target")
@export var target_path: NodePath
## Height above the car origin that the camera orbits / looks at.
@export var target_height_offset := 1.1
## Meters the aim point is pushed ahead of the car at full speed.
@export var look_ahead := 3.0

# ───────────────────────── Distance ─────────────────────────
@export_group("Distance")
@export var base_distance := 5.5
## Extra distance added at reference_speed (camera "pulls back" with speed).
@export var speed_distance_gain := 1.5
## Speed (m/s) treated as "full speed" for FOV, distance, shake, etc.
@export var reference_speed := 25.0
## Hard floor so positional lag can never put the camera inside the car.
@export var hard_min_distance := 3.0
@export var zoom_step := 0.4
@export var min_zoom := -1.5
@export var max_zoom := 2.5

# ───────────────────────── Pitch ─────────────────────────
@export_group("Pitch")
@export_range(-30.0, 60.0, 0.1, "radians_as_degrees") var base_pitch := deg_to_rad(11.0)
## Camera sinks this much at full speed (more "hood-forward" feel).
@export_range(0.0, 30.0, 0.1, "radians_as_degrees") var speed_pitch_drop := deg_to_rad(3.0)
## 0 = ignore car pitch on slopes, 1 = rigidly follow the car's pitch.
@export_range(0.0, 1.0, 0.01) var slope_follow := 0.5
@export_range(-80.0, 0.0, 0.1, "radians_as_degrees") var min_pitch := deg_to_rad(-10.0)
@export_range(0.0, 85.0, 0.1, "radians_as_degrees") var max_pitch := deg_to_rad(70.0)

# ───────────────────────── FOV ─────────────────────────
@export_group("FOV")
@export var base_fov := 70.0
@export var max_fov := 92.0
## >1 keeps FOV low until you're going fast.
@export var fov_speed_curve := 1.5
@export var fov_smoothing := 3.0

# ───────────────────────── Follow ─────────────────────────
@export_group("Follow")
## Horizontal position stiffness. Lower = more lag/stretch behind the car.
@export var position_stiffness := 14.0
## Vertical stiffness. Lower = bumps and suspension travel are filtered out.
@export var vertical_stiffness := 8.0
## How fast the camera swings behind the car when it turns.
@export var yaw_follow_speed := 3.5
@export var pitch_follow_speed := 4.0

# ───────────────────────── Drift ─────────────────────────
@export_group("Drift")
## 0 = always sit behind the car's nose (GTA), 1 = look along velocity (NFS).
@export_range(0.0, 1.0, 0.01) var drift_look_weight := 0.55
## Below this speed (m/s) the camera ignores velocity direction.
@export var drift_min_speed := 4.0
## Slip angle beyond this is ignored so a 90° slide doesn't swing the camera sideways.
@export_range(10.0, 120.0, 1.0, "radians_as_degrees") var max_drift_angle := deg_to_rad(70.0)

# ───────────────────────── Free look ─────────────────────────
@export_group("Free Look")
@export var invert_y := true
@export var mouse_sensitivity := 0.003
## Radians per second at full stick.
@export var joystick_sensitivity := Vector2(3.0, 2.0)
@export var joystick_deadzone := 0.15
@export var stick_response_curve := 2.0
## Seconds without look input before the camera recenters behind the car.
@export var recenter_delay := 1.2
@export var recenter_speed := 3.0
## Camera only auto-recenters while the car is moving faster than this.
@export var recenter_min_speed := 1.0
@export var look_behind_action: StringName = &"look_behind"

# ───────────────────────── Collision ─────────────────────────
@export_group("Collision")
@export var clip_collision := true
@export_flags_3d_physics var collision_mask := 1
@export var collision_radius := 0.35
## How fast the camera eases back out after an obstruction clears.
@export var clip_recover_speed := 4.0
@export_range(0.05, 1.0, 0.01) var min_clip_ratio := 0.2

# ───────────────────────── Shake & Roll ─────────────────────────
@export_group("Shake & Roll")
## Constant rumble amplitude (radians) at full speed.
@export var speed_shake := 0.004
@export var max_trauma_shake := deg_to_rad(3.0)
@export var shake_frequency := 25.0
@export var trauma_decay := 2.5
## Sudden velocity change (m/s²) above this triggers an impact shake.
@export var impact_threshold := 45.0
## Radians of roll per m/s of sideways slide. Flip the sign if it leans the wrong way.
@export var roll_amount := 0.004
@export_range(0.0, 15.0, 0.1, "radians_as_degrees") var max_roll := deg_to_rad(3.0)
@export var roll_smoothing := 4.0

# ───────────────────────── Internal state ─────────────────────────
const SPEED_RATIO_SMOOTHING := 3.0

var _target: Node3D
var _body: RigidBody3D

var _heading_yaw := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _look_yaw := 0.0
var _look_pitch := 0.0
var _back_blend := 0.0
var _idle_time := 0.0

var _dist := 0.0
var _zoom := 0.0
var _zoom_smooth := 0.0
var _speed_ratio := 0.0

var _cam_pos := Vector3.ZERO
var _clip_ratio := 1.0

var _prev_vel := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _roll := 0.0
var _trauma := 0.0
var _noise_t := 0.0
var _noise := FastNoiseLite.new()

var _probe := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	top_level = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	make_current()

	if not target_path.is_empty():
		_target = get_node(target_path) as Node3D
	else:
		_target = get_parent() as Node3D
	_body = _target as RigidBody3D

	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_noise.seed = randi()

	_probe.radius = collision_radius
	_query.shape = _probe
	var exclude: Array[RID] = []
	if _target is CollisionObject3D:
		exclude.append((_target as CollisionObject3D).get_rid())
	_query.exclude = exclude

	if is_instance_valid(_target):
		snap_to_target()


## Teleport the camera straight behind the car (use after respawn/teleport).
func snap_to_target() -> void:
	_update_heading()
	_yaw = _heading_yaw
	_pitch = base_pitch
	_look_yaw = 0.0
	_look_pitch = 0.0
	_back_blend = 0.0
	_zoom_smooth = _zoom
	_dist = base_distance + _zoom_smooth
	_clip_ratio = 1.0
	_speed_ratio = 0.0
	fov = base_fov
	_last_pos = _target.global_position
	_prev_vel = Vector3.ZERO
	_cam_pos = _focal_point() + _orbit_offset(_yaw, _pitch, _dist)
	global_position = _cam_pos
	look_at(_focal_point(), Vector3.UP)


## Call from gameplay code for crashes, landings, boosts, etc. (0..1)
func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sign_y := 1.0 if invert_y else -1.0
		_look_yaw -= event.relative.x * mouse_sensitivity
		_look_pitch += event.relative.y * mouse_sensitivity * sign_y
		_idle_time = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + zoom_step, min_zoom, max_zoom)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	# ── Vehicle state ──────────────────────────────────────
	var vel := _get_target_velocity(delta)
	var speed := vel.length()
	var fwd := -_target.global_basis.z
	var right := _target.global_basis.x
	var forward_speed := vel.dot(fwd)
	_update_heading()

	_speed_ratio = lerpf(_speed_ratio, clampf(speed / reference_speed, 0.0, 1.0),
			1.0 - exp(-SPEED_RATIO_SMOOTHING * delta))

	# ── Free look input ────────────────────────────────────
	_handle_gamepad(delta)
	_look_yaw = wrapf(_look_yaw, -PI, PI)

	_idle_time += delta
	if _idle_time > recenter_delay and speed > recenter_min_speed:
		var k_recenter := 1.0 - exp(-recenter_speed * delta)
		_look_yaw = lerp_angle(_look_yaw, 0.0, k_recenter)
		_look_pitch = lerpf(_look_pitch, 0.0, k_recenter)

	var want_back := InputMap.has_action(look_behind_action) \
			and Input.is_action_pressed(look_behind_action)
	_back_blend = lerpf(_back_blend, 1.0 if want_back else 0.0, 1.0 - exp(-10.0 * delta))

	# ── Chase yaw: blend between nose direction and velocity direction ──
	var chase_yaw := _heading_yaw
	var flat_vel := Vector3(vel.x, 0.0, vel.z)
	var flat_speed := flat_vel.length()
	if forward_speed > 0.0 and flat_speed > drift_min_speed:
		var vel_yaw := atan2(-flat_vel.x, -flat_vel.z)
		var slip := clampf(angle_difference(_heading_yaw, vel_yaw), -max_drift_angle, max_drift_angle)
		var gate := clampf((flat_speed - drift_min_speed) / drift_min_speed, 0.0, 1.0)
		chase_yaw = _heading_yaw + slip * drift_look_weight * gate

	_yaw = lerp_angle(_yaw, chase_yaw, 1.0 - exp(-yaw_follow_speed * delta))

	# ── Chase pitch ────────────────────────────────────────
	var slope := asin(clampf(fwd.y, -1.0, 1.0))
	var target_pitch := base_pitch - speed_pitch_drop * _speed_ratio - slope * slope_follow
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-pitch_follow_speed * delta))

	var final_pitch := clampf(_pitch + _look_pitch, min_pitch, max_pitch)
	_look_pitch = final_pitch - _pitch # stop free-look piling up past the limits
	var final_yaw := _yaw + _look_yaw + PI * _back_blend

	# ── Distance ───────────────────────────────────────────
	_zoom_smooth = lerpf(_zoom_smooth, _zoom, 1.0 - exp(-8.0 * delta))
	var target_dist := base_distance + speed_distance_gain * _speed_ratio + _zoom_smooth
	_dist = lerpf(_dist, target_dist, 1.0 - exp(-4.0 * delta))

	# ── Position with lag (separate horizontal / vertical) ─
	var focal := _focal_point()
	var desired := focal + _orbit_offset(final_yaw, final_pitch, _dist)
	var k_xz := 1.0 - exp(-position_stiffness * delta)
	var k_y := 1.0 - exp(-vertical_stiffness * delta)
	_cam_pos.x = lerpf(_cam_pos.x, desired.x, k_xz)
	_cam_pos.z = lerpf(_cam_pos.z, desired.z, k_xz)
	_cam_pos.y = lerpf(_cam_pos.y, desired.y, k_y)

	var to_cam := _cam_pos - focal
	var dist_now := to_cam.length()
	if dist_now < hard_min_distance and dist_now > 0.001:
		_cam_pos = focal + to_cam / dist_now * hard_min_distance

	# ── Collision: snap in instantly, ease back out ────────
	var target_ratio := 1.0
	if clip_collision:
		target_ratio = maxf(_get_clip_ratio(focal, _cam_pos), min_clip_ratio)
	if target_ratio < _clip_ratio:
		_clip_ratio = target_ratio
	else:
		_clip_ratio = lerpf(_clip_ratio, target_ratio, 1.0 - exp(-clip_recover_speed * delta))

	global_position = focal + (_cam_pos - focal) * _clip_ratio

	# ── Aim slightly ahead of the car ──────────────────────
	var ahead_dir := Vector3(-sin(final_yaw), 0.0, -cos(final_yaw))
	var aim := focal + ahead_dir * look_ahead * _speed_ratio * (1.0 - _back_blend)
	if global_position.distance_squared_to(aim) > 0.001:
		look_at(aim, Vector3.UP)

	# ── FOV ────────────────────────────────────────────────
	var target_fov := lerpf(base_fov, max_fov, pow(_speed_ratio, fov_speed_curve))
	fov = lerpf(fov, target_fov, 1.0 - exp(-fov_smoothing * delta))

	# ── Impact detection, shake, roll ──────────────────────
	var accel := (vel - _prev_vel).length() / maxf(delta, 0.0001)
	if accel > impact_threshold:
		add_shake(clampf((accel - impact_threshold) / 100.0 + 0.2, 0.0, 1.0))
	_prev_vel = vel

	var lateral := vel.dot(right)
	var target_roll := clampf(lateral * roll_amount, -max_roll, max_roll)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-roll_smoothing * delta))

	_noise_t += delta * shake_frequency
	var amp := speed_shake * _speed_ratio * _speed_ratio + max_trauma_shake * _trauma * _trauma
	if amp > 0.00001:
		rotate_object_local(Vector3.RIGHT, _noise.get_noise_2d(_noise_t, 0.0) * amp)
		rotate_object_local(Vector3.UP, _noise.get_noise_2d(_noise_t, 100.0) * amp)
		rotate_object_local(Vector3.BACK, _noise.get_noise_2d(_noise_t, 200.0) * amp)
	rotate_object_local(Vector3.BACK, _roll)
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)


# ───────────────────────── Helpers ─────────────────────────

func _handle_gamepad(delta: float) -> void:
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var length := stick.length()
	if length <= joystick_deadzone:
		return

	var mag := clampf((length - joystick_deadzone) / (1.0 - joystick_deadzone), 0.0, 1.0)
	mag = pow(mag, stick_response_curve)
	var dir := stick / length
	var sign_y := 1.0 if invert_y else -1.0

	_look_yaw -= dir.x * mag * joystick_sensitivity.x * delta
	_look_pitch += dir.y * mag * joystick_sensitivity.y * delta * sign_y
	_idle_time = 0.0


func _update_heading() -> void:
	var fwd := -_target.global_basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	if flat.length_squared() > 0.01:
		# Yaw of the point directly behind the car (matches _orbit_offset).
		_heading_yaw = atan2(-flat.x, -flat.z)


func _get_target_velocity(delta: float) -> Vector3:
	if _body:
		return _body.linear_velocity
	var v := (_target.global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = _target.global_position
	return v


func _focal_point() -> Vector3:
	return _target.global_position + Vector3(0.0, target_height_offset, 0.0)


func _orbit_offset(yaw: float, pitch: float, dist: float) -> Vector3:
	return Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)) * dist


func _get_clip_ratio(from: Vector3, to: Vector3) -> float:
	var motion := to - from
	if motion.length_squared() < 0.0001:
		return 1.0
	_query.transform = Transform3D(Basis.IDENTITY, from)
	_query.motion = motion
	_query.collision_mask = collision_mask
	var result := get_world_3d().direct_space_state.cast_motion(_query)
	if result.is_empty():
		return 1.0
	return result[0]

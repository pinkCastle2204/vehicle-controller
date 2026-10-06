extends RigidBody3D

@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var maxSpeed := 20.0
@export var accelerationCurve : Curve
@export var tireTurnSpeed := 2.0
@export var tireMaxTurnDegrees := 25

var motorInput := 0.0
var handbrake := false

func _physics_process(delta: float) -> void:
	# Continuous input polling avoids missed press/release states
	motorInput = Input.get_axis("decelerate", "accelerate")
	handbrake = Input.is_action_pressed("handbrake")

	DebugDraw3D.draw_arrow_ray(global_position, linear_velocity, 0.5, Color.YELLOW, 0.05)
	_basic_steering_rotation(delta)
	
	for wheel in wheels:
		wheel.force_raycast_update()
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel, delta)
		_do_single_wheel_traction(wheel, delta)

func _basic_steering_rotation(delta: float) -> void:
	var turnInput := Input.get_axis("right", "left") * tireTurnSpeed
	var maxTurnRad := deg_to_rad(tireMaxTurnDegrees)
	
	if turnInput != 0.0:
		$WheelFL.rotation.y = clampf($WheelFL.rotation.y + turnInput * delta, -maxTurnRad, maxTurnRad)
		$WheelFR.rotation.y = clampf($WheelFR.rotation.y + turnInput * delta, -maxTurnRad, maxTurnRad)
	else:
		$WheelFL.rotation.y = move_toward($WheelFL.rotation.y, 0.0, tireTurnSpeed * delta)
		$WheelFR.rotation.y = move_toward($WheelFR.rotation.y, 0.0, tireTurnSpeed * delta)

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func _do_single_wheel_suspension(ray: RaycastWheel) -> void:
	if ray.is_colliding():
		ray.target_position.y = -(ray.restDistance + ray.wheelRad + ray.overExtend)
		var contact := ray.get_collision_point()
		var springUpDir := ray.global_transform.basis.y
		var springLength := ray.global_position.distance_to(contact) - ray.wheelRad
		var offset := ray.restDistance - springLength
		
		ray.wheel.position.y = -springLength
		
		var springForce := ray.springConstant * offset
		var worldVel := _get_point_velocity(contact)
		var relativeVelocity := springUpDir.dot(worldVel)
		var springDampForce := ray.springDamping * relativeVelocity
		
		var forceVector := (springForce - springDampForce) * ray.get_collision_normal()
		var forcePosOffset := ray.wheel.global_position - global_position
		apply_force(forceVector, forcePosOffset)
		DebugDraw3D.draw_arrow_ray(ray.wheel.global_position, forceVector / mass, 0.5, Color.RED, 0.05, true)
	else:
		# Reset wheel position when airborne
		ray.wheel.position.y = -ray.restDistance

func _do_single_wheel_acceleration(ray: RaycastWheel, delta: float) -> void:
	var forwardDir := -ray.global_basis.z
	var vel := forwardDir.dot(linear_velocity)
	
	# Proper rolling angle delta theta = (v * dt) / r
	if ray.wheelRad > 0.0:
		ray.wheel.rotate_x(-(vel * delta) / ray.wheelRad)
		
	if ray.is_colliding():
		var contact := ray.wheel.global_position
		var forcePos := contact - global_position
		
		if ray.is_motor and motorInput != 0.0:
			var speedRatio := clampf(vel / maxSpeed, 0.0, 1.0)
			var ac := 1.0
			if accelerationCurve:
				ac = accelerationCurve.sample_baked(speedRatio)

			var forceVector := forwardDir * acceleration * motorInput * ac
			apply_force(forceVector, forcePos)
			DebugDraw3D.draw_arrow_ray(contact, forceVector / mass, 0.5, Color.BLUE, 0.05, true)

func _do_single_wheel_traction(ray: RaycastWheel, delta: float) -> void:
	if not ray.is_colliding(): 
		return
	
	var tireVel := _get_point_velocity(ray.wheel.global_position)
	var tireSpeed := tireVel.length()
	
	# 1. Lateral traction
	var steerSideDir := ray.global_basis.x
	var steeringXVel := steerSideDir.dot(tireVel)
	
	# Prevent division by zero and micro-oscillations near standstill
	var gripFactor := 0.0
	if tireSpeed > 0.05:
		gripFactor = clampf(absf(steeringXVel / tireSpeed), 0.0, 1.0)
		
	var Xtraction := 1.0
	if ray.gripCurve:
		Xtraction = ray.gripCurve.sample_baked(gripFactor)
	
	if handbrake:
		Xtraction = 0.1
	
	# Soften response (0.4 damping) to avoid single-frame overcorrection flicker
	var lateralFrictionDamp := 0.4
	var desiredAcc := (steeringXVel * Xtraction * lateralFrictionDamp) / delta
	var Xforce := -steerSideDir * desiredAcc * (mass / 4.0)
	
	# 2. Longitudinal traction
	var tireForwardDir := -ray.global_basis.z
	var forwardVel := tireForwardDir.dot(tireVel)
	var zTraction := 0.09
	var zForce := -tireForwardDir * forwardVel * zTraction * ((mass * 9.8) / 4.0)
	
	var forcePosition := ray.wheel.global_position - global_position
	apply_force(Xforce, forcePosition)
	apply_force(zForce, forcePosition)
	DebugDraw3D.draw_arrow_ray(ray.wheel.global_position, Xforce / mass, 0.5, Color.GREEN, 0.05, true)

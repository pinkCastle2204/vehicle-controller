extends RigidBody3D
@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var maxSpeed := 20.0
@export var accelerationCurve : Curve
@export var tireTurnSpeed := 2.0
@export var tireMaxTurnDegrees := 25
var motorInput := 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("accelerate"):
		motorInput =1
	elif event.is_action_released("accelerate"):
		motorInput = 0
	if event.is_action_pressed("decelerate"):
		motorInput = -1
	elif event.is_action_released("decelerate"):
		motorInput = 0

func _basic_steering_rotation(delta:float) -> void:
	var turnInput := Input.get_axis("right","left") * tireTurnSpeed
	
	if turnInput:
		$WheelFL.rotation.y = clampf($WheelFL.rotation.y + turnInput * delta, deg_to_rad(-tireMaxTurnDegrees),deg_to_rad(tireMaxTurnDegrees))
		$WheelFR.rotation.y = clampf($WheelFR.rotation.y + turnInput * delta, deg_to_rad(-tireMaxTurnDegrees),deg_to_rad(tireMaxTurnDegrees))
	else: 
		$WheelFL.rotation.y = move_toward($WheelFL.rotation.y, 0, tireTurnSpeed*delta)
		$WheelFR.rotation.y = move_toward($WheelFR.rotation.y, 0, tireTurnSpeed*delta)

func _physics_process(delta: float) -> void:
	_basic_steering_rotation(delta)
	for wheel in wheels:
		wheel.force_raycast_update()
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel)
		_do_single_wheel_traction(wheel)
		
func _get_point_velocity(point:Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
	
func _do_single_wheel_traction(ray: RaycastWheel) -> void:
	if not ray.is_colliding(): return
	
	var steerSideDir := ray.global_basis.x
	var tireVel := _get_point_velocity(ray.wheel.global_position)
	var steeringXVel := steerSideDir.dot(tireVel)
	var Xtraction := 0.5
	
	var desiredAcc := (steeringXVel*Xtraction) / get_physics_process_delta_time()
	var Xforce := -global_basis.x * desiredAcc * (mass/4.0)
	
	var forcePosition := ray.wheel.global_position - global_position
	apply_force(Xforce,forcePosition)
	DebugDraw3D.draw_arrow_ray(ray.wheel.global_position, Xforce/mass, 0.5, Color.GREEN, 0.05, true)

	
	
	
func _do_single_wheel_acceleration(ray: RaycastWheel) ->void:

	var forwardDir := -ray.global_basis.z
	var vel := forwardDir.dot(linear_velocity)
	ray.wheel.rotate_x(-vel * get_process_delta_time() * 2 * PI *ray.wheelRad)
	if ray.is_colliding():
		var contact := ray.wheel.global_position
		var forcePos := contact - global_position
		if ray.is_motor and motorInput:
			var speedRatio := vel / maxSpeed
			var ac := accelerationCurve.sample_baked(speedRatio)

			var forceVector := forwardDir * acceleration * motorInput *ac
			apply_force(forceVector, forcePos)
			DebugDraw3D.draw_arrow_ray(contact, forceVector/mass, 0.5, Color.BLUE, 0.05, true)

		

func _do_single_wheel_suspension(ray: RaycastWheel) -> void:
	if ray.is_colliding():
		ray.target_position.y = -(ray.restDistance+ray.wheelRad + ray.overExtend)
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
		contact = ray.wheel.global_position
		
		var forcePosOffset := contact - global_position
		apply_force(forceVector, forcePosOffset)
		DebugDraw3D.draw_arrow_ray(contact, forceVector/mass, 0.5, Color.RED, 0.05, true)

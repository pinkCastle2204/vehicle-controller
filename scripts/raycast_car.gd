extends RigidBody3D
@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var maxSpeed := 20.0

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
		
		
		
func _physics_process(delta: float) -> void:
	for wheel in wheels:
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel)
		
func _get_point_velocity(point:Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
	
func _do_single_wheel_acceleration(ray: RaycastWheel) ->void:

		var forwardDir := -ray.global_basis.z
		var vel := forwardDir.dot(linear_velocity)
		ray.wheel.rotate_x(-vel * get_process_delta_time() * 2 * PI *ray.wheelRad)
		if ray.is_colliding() and ray.is_motor and motorInput:
			if vel > maxSpeed:
				return
		
			var contact := ray.wheel.global_position
			var forceVector := forwardDir * acceleration * motorInput
			var forcePos := contact - global_position
			apply_force(forceVector, forcePos)

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
		
		var forceVector := (springForce - springDampForce) * springUpDir
		contact = ray.wheel.global_position
		
		var forcePosOffset := contact - global_position
		apply_force(forceVector, forcePosOffset)
 

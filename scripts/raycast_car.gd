extends RigidBody3D
@export var wheels: Array[RayCast3D]
@export var springConstant := 100.0
@export var springDamping := 2.0
@export var restDistance := 0.5
@export var wheelRad := 0.4

func _physics_process(delta: float) -> void:
	for wheel in wheels:
		_do_single_wheel_suspension(wheel)
		
func _get_point_velocity(point:Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
	
func _do_single_wheel_suspension(suspension_ray: RayCast3D) -> void:
	if suspension_ray.is_colliding():
		suspension_ray.target_position.y = -(restDistance+wheelRad)
		var contact := suspension_ray.get_collision_point()
		var springUpDir := suspension_ray.global_transform.basis.y
		var springLength := suspension_ray.global_position.distance_to(contact) - wheelRad
		var offset := restDistance - springLength
		
		suspension_ray.get_node("wheel").position.y = -springLength
		
		
		var springForce := springConstant * offset
		var worldVel := _get_point_velocity(contact)
		var relativeVelocity := springUpDir.dot(worldVel)
		var springDampForce := springDamping * relativeVelocity
		
		var forceVector := (springForce - springDampForce) * springUpDir
		
		var forcePosOffset := contact - global_position
		apply_force(forceVector, forcePosOffset)
 

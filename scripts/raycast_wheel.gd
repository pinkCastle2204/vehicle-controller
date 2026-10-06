extends RayCast3D
class_name RaycastWheel

@export var springConstant := 100.0
@export var springDamping := 2.0
@export var restDistance := 0.5
@export var overExtend := 0.0
@export var wheelRad := 0.4
@export var is_motor := false

@onready var wheel: Node3D = get_child(0)

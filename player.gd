extends CharacterBody3D

@export_group("Player")
@export var speed = 5.0
@export var jump_velocity = 4.5

@onready var _cam: Node3D = $CameraController

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Handle Jump
	if Input.is_action_pressed("uia_jump") and is_on_floor():
		velocity.y = jump_velocity
	
	
	#Player Movement
	var input_dir = Input.get_vector("uia_sleft", "uia_sright", "uia_sforward", "uia_sback")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		global_rotation = Vector3(0, _cam.get_pan(), 0)
		_cam.reset_pan()
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	
	move_and_slide()

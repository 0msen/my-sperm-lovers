extends CharacterBody3D

# Movement
@export var move_speed: float = 6.0

# Shooting
@export var bullet_scene: PackedScene
@onready var shooting_point: Node3D = $ShootingPoint

# Isometric direction conversion
var iso_forward := Vector3(-1, 0, -1).normalized()
var iso_back := Vector3(1, 0, 1).normalized()
var iso_left := Vector3(-1, 0, 1).normalized()
var iso_right := Vector3(1, 0, -1).normalized()

var aim_direction := Vector3.FORWARD
var is_aiming := false

func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_aim()
	move_and_slide()

func handle_movement() -> void:
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_dir += iso_forward
	if Input.is_action_pressed("move_back"):
		input_dir += iso_back
	if Input.is_action_pressed("move_left"):
		input_dir += iso_left
	if Input.is_action_pressed("move_right"):
		input_dir += iso_right
	
	# Use half of speed when aiming
	input_dir = input_dir.normalized()
	var current_speed := move_speed * (0.5 if is_aiming else 1.0)
	
	velocity.x = input_dir.x * current_speed
	velocity.z = input_dir.z * current_speed


func handle_aim() -> void:
	# Check if right mouse button is held
	is_aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	
	var mouse_pos := get_viewport().get_mouse_position()
	
	# Create a plane at player's Y position
	var plane := Plane(Vector3.UP, global_position.y)
	
	# Cast ray from camera through mouse position
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	
	var intersect = plane.intersects_ray(ray_origin, ray_dir)
	if intersect:
		var look_pos = intersect
		look_pos.y = global_position.y
		
		# Calculate direction and rotate player
		aim_direction = (look_pos - global_position).normalized()
		if aim_direction.length() > 0.1:
			rotation.y = atan2(aim_direction.x, aim_direction.z)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and is_aiming:
		shoot()

func shoot() -> void:
	print("Shoot function called!")  # Add this line
	
	if bullet_scene == null:
		print("Bang! (no bullet scene assigned)")
		return
	
	print("Spawning bullet...")  # Add this line
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = shooting_point.global_position
	bullet.direction = aim_direction
	print("Bullet spawned at: ", shooting_point.global_position)  # Add this line

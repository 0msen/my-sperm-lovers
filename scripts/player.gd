extends CharacterBody3D

# Movement
@export var move_speed: float = 6.0
@export var aim_move_speed_multiplier: float = 0.5 # divison slow

# Shooting
@export var bullet_scene: PackedScene
@export var pellet_count: int = 5
@export var spread_angle: float = 15.0  # degrees
@export var shot_cooldown: float = 0.8

@onready var shooting_point: Node3D = $ShootingPoint
@onready var gun: Node3D = $Gun

# Isometric direction conversion
var iso_forward := Vector3(-1, 0, -1).normalized()
var iso_back := Vector3(1, 0, 1).normalized()
var iso_left := Vector3(-1, 0, 1).normalized()
var iso_right := Vector3(1, 0, -1).normalized()

var aim_direction := Vector3.FORWARD
var is_aiming := false
var can_shoot := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	handle_aiming_input()
	handle_movement()
	handle_aim()
	move_and_slide()

func handle_aiming_input() -> void:
	is_aiming = Input.is_action_pressed("aim")

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
	
	input_dir = input_dir.normalized()
	var current_speed = (move_speed * aim_move_speed_multiplier) if is_aiming else move_speed
	velocity.x = input_dir.x * current_speed
	velocity.z = input_dir.z * current_speed

func handle_aim() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	
	var mouse_pos := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.UP, global_position.y)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	
	var intersect = plane.intersects_ray(ray_origin, ray_dir)
	if intersect:
		var look_pos = intersect
		look_pos.y = global_position.y
		
		aim_direction = (look_pos - global_position).normalized()
		if aim_direction.length() > 0.1:
			rotation.y = atan2(aim_direction.x, aim_direction.z)


func _input(event: InputEvent) -> void:
	# Left click to shoot
	if event.is_action_pressed("shoot") and can_shoot and is_aiming:
		shoot()

func shoot() -> void:
	if bullet_scene == null:
		print("No bullet scene assigned!")
		return
	
	can_shoot = false
	
	# Shotgun spread - spawn multiple pellets
	for i in pellet_count:
		var bullet = bullet_scene.instantiate()
		get_tree().root.add_child(bullet)
		bullet.global_position = shooting_point.global_position
		
		# Add random spread
		var spread_rad = deg_to_rad(spread_angle)
		var random_spread = randf_range(-spread_rad, spread_rad)
		var spread_direction = aim_direction.rotated(Vector3.UP, random_spread)
		bullet.direction = spread_direction
	
	# Trigger gun recoil
	if gun and gun.has_method("recoil"):
		gun.recoil()
	
	# Cooldown timer
	get_tree().create_timer(shot_cooldown).timeout.connect(_reset_shoot)

func _reset_shoot() -> void:
	can_shoot = true

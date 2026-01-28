extends CharacterBody3D
@onready var mesh: MeshInstance3D = $Mesh
# Movement
@export var move_speed: float = 6.0
@export var aim_move_speed_multiplier: float = 0.5 # divison slow
@export var push_speed := 2.0
# Shooting
@export var bullet_scene: PackedScene
@export var pellet_count: int = 3
@export var spread_angle: float = 30.0  # degrees
@export var shot_cooldown: float = 1.5

# Health
@export var max_health: int = 10
@export var knockback_force: float = 15.0
@export var invincibility_duration: float = 0.3

@onready var shooting_point: Node3D = $ShootingPoint
@onready var gun: Node3D = $Gun
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound
@onready var reload_sound: AudioStreamPlayer3D = $ReloadSound
@onready var aim_sound: AudioStreamPlayer3D = $AimSound
@onready var hp_bar: Node3D = $HPBar
@onready var activation_radius: Area3D = $ActivationRadius
@export var conductive := true
# Isometric direction conversion
var iso_forward := Vector3(-1, 0, -1).normalized()
var iso_back := Vector3(1, 0, 1).normalized()
var iso_left := Vector3(-1, 0, 1).normalized()
var iso_right := Vector3(1, 0, -1).normalized()

var aim_direction := Vector3.FORWARD
var is_aiming := false
var can_shoot := true

# Health state
var health: int
var is_invincible := false
var knockback_velocity := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	health = max_health
	if conductive:
		add_to_group("conductive")
	add_to_group("player")
	if hp_bar:
		hp_bar.update_health(health, max_health)
	if activation_radius:
		activation_radius.body_entered.connect(_on_activation_radius_body_entered)
		activation_radius.body_exited.connect(_on_activation_radius_body_exited)
		# Deactivate enemies outside range at game start
		_deactivate_distant_enemies.call_deferred()  

func _physics_process(delta: float) -> void:
	handle_aiming_input()
	handle_movement()
	handle_aim()

	# Apply knockback on top of movement velocity
	velocity += knockback_velocity

	move_and_slide()
	_push_character_bodies()
	_handle_push_collision()
	# Decay knockback after movement (so first frame gets full knockback)
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 40.0 * delta)
func _handle_push_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()

		if body is CharacterBody3D and body.is_in_group("pushable"):
			var push_dir = collision.get_normal() * -1
			push_dir.y = 0
			push_dir = push_dir.normalized()

			body.velocity.x = push_dir.x * push_speed
			body.velocity.z = push_dir.z * push_speed
			body.move_and_slide()
func _push_character_bodies():
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var body = col.get_collider()

		if body and body.has_method("apply_push"):
			var dir = -col.get_normal()
			body.apply_push(dir)
func handle_aiming_input() -> void:
	is_aiming = Input.is_action_pressed("aim")
	if Input.is_action_just_pressed("aim"): aim_sound.play()

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

	# Reduce input influence during knockback (knockback takes priority)
	var knockback_strength = knockback_velocity.length()
	var input_scale = clampf(1.0 - (knockback_strength / knockback_force), 0.0, 1.0)

	velocity.x = input_dir.x * current_speed * input_scale
	velocity.z = input_dir.z * current_speed * input_scale

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
	
	# Play shoot sound
	if shoot_sound and shoot_sound.stream: shoot_sound.play()
	
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
		
	# Trigger gun recoil and Play reload sound (pump-action style)
	if gun and gun.has_method("recoil"): gun.recoil()
	if reload_sound and reload_sound.stream: reload_sound.play()
	
	# Cooldown timer
	get_tree().create_timer(shot_cooldown).timeout.connect(_reset_shoot)

func _reset_shoot() -> void:
	can_shoot = true

func notify_nearby_violence(violence_position: Vector3) -> void:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy.has_method("_on_nearby_violence"):
			enemy._on_nearby_violence(violence_position)


func take_damage(
	amount: int,
	attacker_position: Vector3,
	apply_knockback := true
) -> void:
	if is_invincible:
		return

	health -= amount
	print("Player took ", amount, " damage! Health: ", health)
	if mesh and mesh.material_override:
		mesh.material_override.emission = Color.GREEN

		get_tree().create_timer(0.15).timeout.connect(_reset_burn_effect)

	if hp_bar:
		hp_bar.update_health(health, max_health)
	if hp_bar:
		hp_bar.update_health(health, max_health)

	# Apply knockback away from attacker
	if apply_knockback:
		var knockback_dir = (global_position - attacker_position).normalized()
		knockback_dir.y = 0
		knockback_velocity = knockback_dir * knockback_force

	is_invincible = true
	get_tree().create_timer(invincibility_duration).timeout.connect(_end_invincibility)
	
	if health <= 0:
		die()
		
func _reset_burn_effect() -> void:
	if mesh and mesh.material_override:
		mesh.material_override.emission = Color.BLACK

func _end_invincibility() -> void:
	is_invincible = false


func die() -> void:
	print("Player died!")
	queue_free()


func _deactivate_distant_enemies() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not activation_radius:
		return
	var nearby_enemies: Array[Node3D] = []
	for body in activation_radius.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			nearby_enemies.append(body)
	# Deactivate all enemies NOT in range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy not in nearby_enemies and enemy.has_method("deactivate"):
			enemy.deactivate()


func _on_activation_radius_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and body.has_method("activate"):
		body.activate()


func _on_activation_radius_body_exited(body: Node3D) -> void:
	if body.is_in_group("enemies") and body.has_method("deactivate"):
		body.deactivate()

extends CharacterBody3D

@export var move_speed: float = 2.0
@export var wander_range: float = 5.0
@export var max_health: int = 3
var health: int
@export var detection_range: float = 10.0
@export var chase_speed: float = 3.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5
@export var stop_distance: float = 1.2
@export var separation_radius: float = 2.0
@export var separation_force: float = 1.5
@export var model_rotation_offset: float = -PI/2  # Offset to align model forward with movement

var wander_target: Vector3
var home_position: Vector3
var current_target: Node3D = null
var is_chasing: bool = false
var is_aggro: bool = false
var is_active: bool = false
var can_attack: bool = true
var wander_stuck_timer: float = 0.0
var last_position: Vector3

@onready var attack_hitbox: Area3D = $AttackHitbox
@onready var hp_bar: Node3D = $HPBar
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	home_position = global_position
	last_position = global_position
	health = max_health
	add_to_group("enemies")
	pick_new_wander_target()
	print("Sibling spawned on layers: ", collision_layer, " groups: ", get_groups())

	# Connect attack hitbox signal
	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

	# Wait for navigation to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Start dormant until player is in range
	deactivate()


func _physics_process(delta: float) -> void:
	# Only chase if aggro (has been shot)
	if is_aggro:
		detect_targets()

	# Stuck detection for wandering
	if not is_aggro:
		var moved_dist = (global_position - last_position).length()
		if moved_dist < 0.05:
			wander_stuck_timer += delta
			if wander_stuck_timer > 2.0:
				pick_new_wander_target()
				wander_stuck_timer = 0.0
		else:
			wander_stuck_timer = 0.0
		last_position = global_position

	var base_velocity := Vector3.ZERO

	if is_aggro and is_chasing and is_instance_valid(current_target):
		# Set navigation target
		nav_agent.target_position = current_target.global_position

		var dist_to_target = (current_target.global_position - global_position).length()

		# Only move if not within stop distance
		if dist_to_target > stop_distance:
			var direction: Vector3

			# Use navigation if path is available
			if not nav_agent.is_navigation_finished():
				var next_pos = nav_agent.get_next_path_position()
				var horizontal_diff = next_pos - global_position
				horizontal_diff.y = 0
				if horizontal_diff.length() > 0.1:
					direction = horizontal_diff.normalized()
				else:
					# Fallback to direct path if nav returns current position
					var direct_diff = current_target.global_position - global_position
					direct_diff.y = 0
					direction = direct_diff.normalized()
			else:
				# Fallback to direct path
				var direct_diff = current_target.global_position - global_position
				direct_diff.y = 0
				direction = direct_diff.normalized()

			base_velocity = direction * chase_speed
	else:
		# WANDER state: wander around
		is_chasing = false
		current_target = null

		var to_target = wander_target - global_position
		to_target.y = 0

		# Pick new target when close or stuck (too far and not moving)
		if to_target.length() < 0.5:
			pick_new_wander_target()
		elif to_target.length() > 0.1:
			var direction = to_target.normalized()
			base_velocity = direction * move_speed

	# Add separation from other enemies
	var separation = get_separation_from_enemies()
	velocity = base_velocity + separation

	move_and_slide()

	# Face player directly when aggro, otherwise face movement direction
	if is_aggro and is_instance_valid(current_target):
		var look_dir = current_target.global_position - global_position
		look_dir.y = 0
		if look_dir.length() > 0.1:
			rotation.y = atan2(look_dir.x, look_dir.z) + model_rotation_offset
	elif velocity.length() > 0.1:
		rotation.y = atan2(velocity.x, velocity.z) + model_rotation_offset

	# Check for continuous attack while overlapping
	check_continuous_attack()


func pick_new_wander_target() -> void:
	var random_offset = Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	wander_target = home_position + random_offset


func get_separation_from_enemies() -> Vector3:
	var separation := Vector3.ZERO

	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity == self:
			continue

		# Use horizontal distance only
		var horizontal_diff = global_position - entity.global_position
		horizontal_diff.y = 0
		var dist = horizontal_diff.length()

		if dist < separation_radius and dist > 0.01:
			var away_dir = horizontal_diff.normalized()
			# Stronger push when closer
			separation += away_dir * (separation_force * (1.0 - dist / separation_radius))

	return separation


func detect_targets() -> void:
	# Only target the player
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var horizontal_diff = player.global_position - global_position
		horizontal_diff.y = 0
		var dist = horizontal_diff.length()
		if dist < detection_range:
			current_target = player
			is_chasing = true
			return

	is_chasing = false
	current_target = null


func take_damage(amount: int) -> bool:
	health -= amount
	print("Sibling took ", amount, " damage! Health: ", health)

	if hp_bar:
		hp_bar.update_health(health, max_health)

	# Become aggro when shot
	if not is_aggro:
		become_aggro()

	if health <= 0:
		die()
		return true
	return false


func die() -> void:
	print("Sibling died!")
	queue_free()


func become_aggro() -> void:
	if is_aggro:
		return
	is_aggro = true
	print("Sibling sperm became aggro!")


func _on_attack_hitbox_body_entered(body: Node3D) -> void:
	if not is_aggro:
		return
	if not can_attack:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("take_damage"):
		return

	body.take_damage(attack_damage, global_position)
	can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(_reset_attack)


func check_continuous_attack() -> void:
	if not is_aggro or not can_attack or not attack_hitbox:
		return
	for body in attack_hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
			can_attack = false
			get_tree().create_timer(attack_cooldown).timeout.connect(_reset_attack)
			break


func _reset_attack() -> void:
	can_attack = true


func activate() -> void:
	if is_active:
		return
	is_active = true
	set_physics_process(true)


func deactivate() -> void:
	if is_aggro and is_chasing:
		return  # Don't deactivate mid-chase
	if not is_active:
		return
	is_active = false
	set_physics_process(false)
	velocity = Vector3.ZERO

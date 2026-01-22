extends CharacterBody3D

@export var move_speed: float = 1.5
@export var wander_range: float = 3.0
@export var health: int = 5
@export var detection_range: float = 8.0
@export var chase_speed: float = 4.0
@export var attack_damage: int = 2
@export var knockback_force: float = 12.0
@export var attack_cooldown: float = 1.0
@export var stop_distance: float = 1.5
@export var separation_radius: float = 3.0
@export var separation_force: float = 2.0

var wander_target: Vector3
var home_position: Vector3
var current_target: Node3D = null
var is_chasing: bool = false
var can_attack: bool = true

@onready var attack_hitbox: Area3D = $AttackHitbox


func _ready() -> void:
	home_position = global_position
	add_to_group("enemies")
	pick_new_wander_target()

	# Connect attack hitbox signal
	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)


func _physics_process(_delta: float) -> void:
	# Check for nearby targets (player or sibling sperm)
	detect_targets()

	var base_velocity := Vector3.ZERO

	if is_chasing and is_instance_valid(current_target):
		# Use horizontal distance only (ignore Y height difference)
		var horizontal_diff = current_target.global_position - global_position
		horizontal_diff.y = 0
		var dist_to_target = horizontal_diff.length()

		# Only move if not within stop distance
		if dist_to_target > stop_distance:
			var direction = horizontal_diff.normalized()
			base_velocity = direction * chase_speed
	else:
		# PATROL state: wander around
		is_chasing = false
		current_target = null

		var direction = (wander_target - global_position).normalized()
		direction.y = 0
		base_velocity = direction * move_speed

		# Pick new target when close
		if global_position.distance_to(wander_target) < 0.5:
			pick_new_wander_target()

	# Add separation from other white blood cells
	var separation = get_separation_from_other_wbcs()
	velocity = base_velocity + separation

	move_and_slide()

	# Face movement direction
	if velocity.length() > 0.1:
		rotation.y = atan2(velocity.x, velocity.z)


func pick_new_wander_target() -> void:
	wander_target = Vector3(
		home_position.x + randf_range(-wander_range, wander_range),
		global_position.y,
		home_position.z + randf_range(-wander_range, wander_range)
	)


func get_separation_from_other_wbcs() -> Vector3:
	var separation := Vector3.ZERO

	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity == self:
			continue
		# Only separate from other white blood cells (entities without become_aggro)
		if entity.has_method("become_aggro"):
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
	var nearest_target: Node3D = null
	var nearest_distance: float = detection_range

	# Check for player (use horizontal distance only)
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var horizontal_diff = player.global_position - global_position
		horizontal_diff.y = 0
		var dist = horizontal_diff.length()
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_target = player

	# Check for sibling sperm (they're in "enemies" group but have "become_aggro" method)
	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity == self:
			continue
		if not entity.has_method("become_aggro"):
			continue  # Skip other white blood cells
		var horizontal_diff = entity.global_position - global_position
		horizontal_diff.y = 0
		var dist = horizontal_diff.length()
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_target = entity

	if nearest_target:
		current_target = nearest_target
		is_chasing = true
	else:
		is_chasing = false
		current_target = null


func take_damage(amount: int) -> void:
	health -= amount
	print("White blood cell took ", amount, " damage! Health: ", health)
	if health <= 0:
		print("White blood cell died!")
		queue_free()


func _on_attack_hitbox_body_entered(body: Node3D) -> void:
	if not can_attack:
		return

	# Attack player
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_damage, global_position)
		can_attack = false
		get_tree().create_timer(attack_cooldown).timeout.connect(_reset_attack)
		return

	# Attack sibling sperm (enemies with become_aggro method)
	if body.is_in_group("enemies") and body.has_method("become_aggro") and body.has_method("take_damage"):
		# WBC deals damage with knockback to siblings too
		body.take_damage(attack_damage)
		can_attack = false
		get_tree().create_timer(attack_cooldown).timeout.connect(_reset_attack)


func _reset_attack() -> void:
	can_attack = true

extends CharacterBody3D

@export var static_mode: bool = false
@export var move_speed: float = 2.0
@export var wander_range: float = 5.0
@export var max_health: int = 3
@export var detection_range: float = 10.0
@export var chase_speed: float = 3.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5
@export var stop_distance: float = 1.2
@export var separation_radius: float = 2.0
@export var separation_force: float = 1.5
@export var model_rotation_offset: float = -PI/2

# Distance within which nearby violence wakes this sperm
@export var wake_on_violence_range: float = 12.0
@export var casual_talk_block: String = "SpermDialogs"
@export var talk_max_distance: float = 4.5

# Local variables
var health: int
var wander_target: Vector3
var home_position: Vector3
var current_target: Node3D = null
var is_chasing: bool = false
var is_aggro: bool = false
var is_active: bool = true
var can_attack: bool = true
var wander_stuck_timer: float = 0.0
var last_position: Vector3

# Shoot-to-talk support
var player_in_hitbox: bool = false
var is_dead: bool = false

# Node references
@onready var attack_hitbox: Area3D = $AttackHitbox
@onready var hp_bar: Node3D = $HPBar
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialog_system: Control = $DialogSystem/ControlNode

func _ready() -> void:
	home_position = global_position
	last_position = global_position
	health = max_health
	add_to_group("enemies")

	print("Sibling spawned – layers: ", collision_layer, " groups: ", get_groups())
	if not static_mode: pick_new_wander_target()

	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_hitbox_body_entered)
		attack_hitbox.body_exited.connect(_on_hitbox_body_exited)

	# Let navigation initialize and be happy
	await get_tree().physics_frame
	await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	# Completely frozen when static & peaceful
	if static_mode and not is_aggro:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# Update target only when aggro
	if is_aggro: detect_targets()
	# Wandering + stuck recovery (only when peaceful and not forced static)
	if not is_aggro and not static_mode:
		var moved_dist = (global_position - last_position).length()
		if moved_dist < 0.05:
			wander_stuck_timer += delta
			if wander_stuck_timer > 2.0:
				pick_new_wander_target()
				wander_stuck_timer = 0.0
		else:
			wander_stuck_timer = 0.0
		last_position = global_position

	# Decide base movement
	var base_velocity := Vector3.ZERO

	if is_aggro and is_chasing and is_instance_valid(current_target):
		nav_agent.target_position = current_target.global_position
		var dist_to_target = (current_target.global_position - global_position).length()

		if dist_to_target > stop_distance:
			var direction := Vector3.ZERO

			if not nav_agent.is_navigation_finished():
				var next_pos = nav_agent.get_next_path_position()
				var diff = next_pos - global_position
				diff.y = 0
				if diff.length() > 0.1:
					direction = diff.normalized()

			# Fallback to direct path if nav failed or finished
			if direction == Vector3.ZERO:
				var diff = current_target.global_position - global_position
				diff.y = 0
				if diff.length() > 0.1:
					direction = diff.normalized()
			base_velocity = direction * chase_speed

	else:
		# Peaceful wandering (only if not static)
		is_chasing = false
		current_target = null

		if not static_mode:
			var to_target = wander_target - global_position
			to_target.y = 0

			if to_target.length() < 0.5: pick_new_wander_target()
			elif to_target.length() > 0.1: base_velocity = to_target.normalized() * move_speed

	# Apply separation force & move
	var separation = get_separation_from_enemies()
	velocity = base_velocity + separation
	move_and_slide()

	# ONLY rotate when aggro (hostile mode)
	if is_aggro:
		var look_target: Vector3 = Vector3.ZERO

		if is_instance_valid(current_target): look_target = current_target.global_position
		elif velocity.length() > 0.1: look_target = global_position + velocity

		if look_target != Vector3.ZERO:
			var look_dir = look_target - global_position
			look_dir.y = 0
			if look_dir.length() > 0.05:
				rotation.y = atan2(look_dir.x, look_dir.z) + model_rotation_offset

	# Attack only when aggro
	check_continuous_attack()

# Input checker (for interaction)
func _input(event: InputEvent) -> void:
	if is_aggro: return
	if not player_in_hitbox: return
	if not dialog_system: return
	if Input.is_action_pressed("aim"): return

	if event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		_trigger_dialogue()

func _trigger_dialogue() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist > talk_max_distance: return
		dialog_system.start_dialogue(casual_talk_block, false)
		print("[Sperm] Player poked me → said: ", casual_talk_block)

# Helper functions
func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"): player_in_hitbox = true
func _on_hitbox_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"): player_in_hitbox = false

func _on_nearby_violence(violence_position: Vector3) -> void:
	if is_aggro: return
	if global_position.distance_to(violence_position) < wake_on_violence_range: become_aggro()

func pick_new_wander_target() -> void:
	var offset = Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	wander_target = home_position + offset

func get_separation_from_enemies() -> Vector3:
	var push := Vector3.ZERO
	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity == self: continue
		var diff = global_position - entity.global_position
		diff.y = 0
		var dist = diff.length()
		if dist < separation_radius and dist > 0.01:
			var dir = diff.normalized()
			push += dir * (separation_force * (1.0 - dist / separation_radius))
	return push

func detect_targets() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var diff = player.global_position - global_position
		diff.y = 0
		if diff.length() < detection_range:
			current_target = player
			is_chasing = true
			return
	current_target = null
	is_chasing = false

func take_damage(amount: int) -> bool:
	health -= amount
	print("Sibling took ", amount, " damage! Health: ", health)
	if hp_bar: hp_bar.update_health(health, max_health)
	if not is_aggro: become_aggro()
	if health <= 0:
		die()
		return true
	return false

func become_aggro() -> void:
	if is_aggro: return
	is_aggro = true
	print("Sibling sperm became aggro!")
	if GameManager:
		GameManager.on_enemy_aggro()

func die() -> void:
	if is_dead: return  # Prevent double-death from multiple pellets in same frame
	is_dead = true
	print("Sibling died!")
	# Wake nearby siblings FIRST so they become aggro before we decrement the count
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy != self and enemy.has_method("_on_nearby_violence"):
			enemy._on_nearby_violence(global_position)
	# Now notify GameManager (karma and aggro count)
	if GameManager:
		GameManager.add_karma_xp(-10.0)  # Bad action: -10 XP
		if is_aggro:
			GameManager.on_enemy_died()
	queue_free()

func check_continuous_attack() -> void:
	if not is_aggro or not can_attack or not attack_hitbox: return
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

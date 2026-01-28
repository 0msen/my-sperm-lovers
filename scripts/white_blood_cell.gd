extends CharacterBody3D

const DeathSplash = preload("res://scenes/effects/death_splash.tscn")

# Exported variable
@export var static_mode: bool = false
@export var move_speed: float = 1.5
@export var wander_range: float = 3.0
@export var max_health: int = 5
@export var detection_range: float = 10.0
@export var chase_speed: float = 2.5
@export var attack_damage: int = 2
@export var knockback_force: float = 12.0
@export var attack_cooldown: float = 1.0
@export var stop_distance: float = 1.5
@export var separation_radius: float = 3.0
@export var separation_force: float = 2.0
@export var model_rotation_offset: float = -PI/2
# Wake-up range for nearby violence (shooting / death nearby)
@export var wake_on_violence_range: float = 14.0      # Slightly larger than sperm for WBC "alertness"

# Dialogue settings
@export var casual_talk_block: String = "WhiteCellDialogs" # Default: Refere to art/JSON
@export var talk_max_distance: float = 4.5

# Internal state
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

# Shoot-to-talk
var player_in_hitbox: bool = false
var is_dead: bool = false

# Nodes
@onready var attack_hitbox: Area3D = $AttackHitbox
@onready var hp_bar: Node3D = $HPBar
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialog_system: Control = $DialogSystem/ControlNode

func _ready() -> void:
	home_position = global_position
	last_position = global_position
	health = max_health
	add_to_group("enemies")

	print("WhiteCell spawned – layers: ", collision_layer, " groups: ", get_groups())
	if not static_mode: pick_new_wander_target()

	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_hitbox_body_entered)
		attack_hitbox.body_exited.connect(_on_hitbox_body_exited)

	# Give nav time to init
	await get_tree().physics_frame
	await get_tree().physics_frame


func _physics_process(delta: float) -> void:
	# Completely frozen when static & peaceful
	if static_mode and not is_aggro:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Detect player when aggro
	if is_aggro: detect_targets()

	# Stuck detection & wander (only peaceful + not static)
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

	# Movement
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
				if diff.length() > 0.1: direction = diff.normalized()

			if direction == Vector3.ZERO:
				var diff = current_target.global_position - global_position
				diff.y = 0
				if diff.length() > 0.1: direction = diff.normalized()
			base_velocity = direction * chase_speed

	else:
		# Peaceful wandering (only if allowed)
		is_chasing = false
		current_target = null

		if not static_mode:
			var to_target = wander_target - global_position
			to_target.y = 0
			if to_target.length() < 0.5:
				pick_new_wander_target()
			elif to_target.length() > 0.1:
				base_velocity = to_target.normalized() * move_speed

	# Separation + final velocity
	var separation = get_separation_from_enemies()
	velocity = base_velocity + separation
	move_and_slide()

	# Facing
	if is_aggro:
		if is_instance_valid(current_target):
			var look_dir = current_target.global_position - global_position
			look_dir.y = 0
			if look_dir.length() > 0.1:
				rotation.y = atan2(look_dir.x, look_dir.z) + model_rotation_offset
		elif velocity.length() > 0.1:
			rotation.y = atan2(velocity.x, velocity.z) + model_rotation_offset
	check_continuous_attack()


# Shoot-to-talk (peaceful only)
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
	if not player: return
	var dist = global_position.distance_to(player.global_position)
	if dist > talk_max_distance: return
	dialog_system.start_dialogue(casual_talk_block, false)
	print("[WhiteCell] Player interacted → said: ", casual_talk_block)


# Hitbox for shoot-to-talk and other helper functions
func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"): player_in_hitbox = true
func _on_hitbox_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"): player_in_hitbox = false

func pick_new_wander_target() -> void:
	wander_target = home_position + Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)

func get_separation_from_enemies() -> Vector3:
	var separation := Vector3.ZERO
	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity == self: continue
		var diff = global_position - entity.global_position
		diff.y = 0
		var dist = diff.length()
		if dist < separation_radius and dist > 0.01:
			var away_dir = diff.normalized()
			separation += away_dir * (separation_force * (1.0 - dist / separation_radius))
	return separation

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
	if is_dead:
		return false
	health -= amount
	print("White blood cell took ", amount, " damage! Health: ", health)
	if hp_bar: hp_bar.update_health(health, max_health)
	if not is_aggro: become_aggro()
	if health <= 0:
		die()
		return true
	return false

func die() -> void:
	if is_dead: return  # Prevent double-death from multiple pellets
	is_dead = true

	print("White blood cell died!")
	# Spawn death effect
	var splash = DeathSplash.instantiate()
	var colors: Array[Color] = [
		Color(0.95, 0.95, 0.95), # White
		Color(1.0, 0.4, 0.6),    # Pink
		Color(0.5, 0.0, 0.15),   # Maroon
	]
	splash.set_colors(colors)
	var death_pos = global_position
	get_tree().current_scene.add_child(splash)
	splash.global_position = death_pos
	# Wake nearby enemies FIRST so they become aggro before we decrement the count
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

func become_aggro() -> void:
	if is_aggro: return
	is_aggro = true
	print("White blood cell became aggro!")
	if GameManager:
		GameManager.on_enemy_aggro()


func _on_nearby_violence(violence_position: Vector3) -> void:
	if is_aggro: return
	var dist = global_position.distance_to(violence_position)
	if dist < wake_on_violence_range: become_aggro()

func check_continuous_attack() -> void:
	if not is_aggro or not can_attack or not attack_hitbox: return

	for body in attack_hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)

			# Knockback on player
			if body.has_method("apply_knockback") or body.has_method("knockback_velocity"):
				var dir = (body.global_position - global_position).normalized()
				var knock = dir * knockback_force
				if body.has_method("apply_knockback"): body.apply_knockback(knock)
				elif "knockback_velocity" in body: body.knockback_velocity += knock
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

extends CharacterBody3D

const DeathSplash = preload("res://scenes/effects/death_splash.tscn")

# Configuration
@export_group("Boss Stats")
@export var max_health: int = 100

@export_group("Movement")
@export var chase_speed: float = 4.5
@export var stop_distance: float = 2.0
@export var model_rotation_offset: float = -PI/2

@export_group("Combat")
@export var detection_range: float = 15.0
@export var attack_damage: int = 2
@export var attack_cooldown: float = 1.2
@export var summon_cooldown: float = 10.0
@export var minions_per_summon: int = 3
@export var summon_distance: float = 3.0

# State
var health: int
var is_aggro := false
var current_target: Node3D = null
var can_attack := true
var is_dead := false

var summon_timer: float = 0.0
var summoned_minions: Array = []

# Nodes
@onready var attack_hitbox: Area3D = $AttackHitbox
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialog_system: Control = $DialogSystem/ControlNode

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	add_to_group("boss")
	
	# Give navigation system a moment to initialize
	await get_tree().physics_frame
	await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_aggro: return

	# Timers & periodic actions
	summon_timer += delta
	if summon_timer >= summon_cooldown:
		summon_minions()
		summon_timer = 0.0

	_update_target_and_movement()
	_rotate_towards_target()
	_try_perform_attack()

func _update_target_and_movement() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		current_target = null
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > detection_range:
		current_target = null
		return

	current_target = player

	var distance_to_target = global_position.distance_to(current_target.global_position)
	if distance_to_target <= stop_distance:
		velocity = Vector3.ZERO
		return

	# Try navigation agent first
	var direction := Vector3.ZERO
	if nav_agent:
		nav_agent.target_position = current_target.global_position
		if not nav_agent.is_navigation_finished():
			var next_pos = nav_agent.get_next_path_position()
			direction = (next_pos - global_position).normalized()
			direction.y = 0

	# Fallback to direct line if needed
	if direction.length_squared() < 0.01:
		direction = (current_target.global_position - global_position).normalized()
		direction.y = 0

	velocity = direction * chase_speed
	move_and_slide()

func _rotate_towards_target() -> void:
	if not current_target: return
	var look_direction = current_target.global_position - global_position
	look_direction.y = 0

	if look_direction.length_squared() > 0.0025:
		rotation.y = atan2(look_direction.x, look_direction.z) + model_rotation_offset

func _try_perform_attack() -> void:
	if not can_attack: return

	for body in attack_hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
			can_attack = false
			get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
			break

# Aggro & summoning
func become_aggro() -> void:
	if is_aggro: return
	is_aggro = true
	dialog_system.start_dialogue("MonsterEnding_Bad")
	print("BOSS AGGRO!")

	if GameManager: GameManager.on_enemy_aggro()
	summon_minions()

func summon_minions() -> void:
	if minions_per_summon <= 0: return
	print("Boss summons ", minions_per_summon, " minions!")
	var minion_scene = preload("res://scenes/enemies/sibling_sperm.tscn")
	if not minion_scene: return

	for i in minions_per_summon:
		var minion = minion_scene.instantiate()
		get_tree().current_scene.add_child(minion)
		var angle = (float(i) / minions_per_summon) * TAU
		var offset = Vector3(cos(angle), 0, sin(angle)) * summon_distance
		minion.global_position = global_position + offset
		summoned_minions.append(minion)
		
		if minion.has_method("become_aggro"): minion.become_aggro()

# Damage & death
func take_damage(amount: int) -> bool:
	if is_dead: return false
	health -= amount
	print("Boss took ", amount, " damage → ", health, "/", max_health)

	if not is_aggro: become_aggro()
	if health <= 0:
		die()
		return true

	return false

func die() -> void:
	if is_dead: return
	is_dead = true
	print("BOSS DEFEATED!")
	_make_minions_static()
	_spawn_death_splash()

	if GameManager:
		GameManager.add_karma_xp(-50.0)
		if is_aggro: GameManager.on_enemy_died()

	visible = false
	set_physics_process(false)
	check_all_minions_dead()

func _make_minions_static() -> void:
	summoned_minions = summoned_minions.filter(is_instance_valid)

	for minion in summoned_minions:
		minion.static_mode = true
		minion.is_aggro = true
		minion.is_chasing = false
		minion.current_target = null
		minion.velocity = Vector3.ZERO

		if not minion.tree_exiting.is_connected(_on_minion_died):
			minion.tree_exiting.connect(_on_minion_died)

func _spawn_death_splash() -> void:
	var splash = DeathSplash.instantiate()
	splash.set_colors([
		Color(1.0, 0.0, 0.0),
		Color(0.8, 0.0, 0.3),
		Color(0.3, 0.0, 0.1)
	] as Array[Color])

	get_tree().current_scene.add_child(splash)
	splash.global_position = global_position

func _on_minion_died() -> void:
	await get_tree().process_frame
	check_all_minions_dead()

func check_all_minions_dead() -> void:
	summoned_minions = summoned_minions.filter(is_instance_valid)

	if summoned_minions.is_empty():
		print("All minions dead - opening arena!")
		if GameManager: GameManager._switch_to_default_music()
		var arena = get_tree().get_first_node_in_group("boss_arena")
		if arena and arena.has_method("on_boss_defeated"): arena.on_boss_defeated()

		queue_free()

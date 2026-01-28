extends Node3D

# Node references
@onready var boss_area: Area3D = $BossArea
@onready var boss: CharacterBody3D = $Boss
@onready var no_escape_doors: Node3D = $NoEscapeDoors
@onready var dialog_system: Control = $DialogSystem/ControlNode

# State variables
var boss_fight_started: bool = false
var player_in_arena: bool = false

func _ready() -> void:
	# Add to group so boss can find us later
	add_to_group("boss_arena")
	
	# Hide the doors initially
	if no_escape_doors:
		no_escape_doors.visible = false
		# Also disable collision initially
		for child in no_escape_doors.get_children():
			if child is StaticBody3D:
				child.set_collision_layer_value(1, false)
				child.set_collision_mask_value(1, false)
	
	# Connect boss area signals
	if boss_area:
		boss_area.body_entered.connect(_on_boss_area_body_entered)
		boss_area.body_exited.connect(_on_boss_area_body_exited)
	
	print("Boss Arena initialized - doors hidden")

func _on_boss_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not boss_fight_started:
		player_in_arena = true
		start_boss_fight()

func _on_boss_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_arena = false

func start_boss_fight() -> void:
	if boss_fight_started: return
	
	dialog_system.start_dialogue("DoorethyEnding_Bad")
	boss_fight_started = true
	print("Boss fight started!")
	
	# Stop all music for eerie silence
	if GameManager:
		GameManager.default_music.stop()
		GameManager.aggro_music.stop()
		print("All music stopped - eerie silence...")
	
	# Make doors visible and enable collision
	if no_escape_doors:
		no_escape_doors.visible = true
		
		# Enable collision for all door bodies
		for child in no_escape_doors.get_children():
			if child is StaticBody3D:
				child.set_collision_layer_value(1, true)
				child.set_collision_mask_value(1, true)
	
	# Trigger boss aggro after a brief delay for atmosphere
	await get_tree().create_timer(25.0).timeout
	if boss and boss.has_method("become_aggro"):
		boss.become_aggro()

func on_boss_defeated() -> void:
	print("Boss defeated - opening arena")
	
	# Hide doors again to let player escape
	if no_escape_doors:
		no_escape_doors.visible = false
		
		# Disable collision
		for child in no_escape_doors.get_children():
			if child is StaticBody3D:
				child.set_collision_layer_value(1, false)
				child.set_collision_mask_value(1, false)

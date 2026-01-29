extends Node3D
## Main elevator controller that integrates zone validation, button, and spawner
## Manages elevator ascent based on validation

# --- Configuration ---
@export var target_height: float = 20.0
@export var speed: float = 3.0
@export var gate_speed: float = 10.0
@export var auto_depart_on_valid: bool = false

# --- State ---
var can_rise: bool = false
var gate_closing: bool = false
var initial_gate_position: Vector3
var is_departed: bool = false
var valves_complete: bool = false  # Track if pacifist route completed

# --- Node References ---
@onready var gate: Node3D = $Edoor_mesh
@onready var body: Node3D = $Ebody_mesh
@onready var elevator_zone: Area3D = $ElevatorZone
@onready var button: Node3D = $button

func _ready() -> void:
	add_to_group("elevator")
	
	# Store initial gate position
	if gate:
		initial_gate_position = gate.position
	
	# Connect zone signals (keeping your original ones)
	if elevator_zone:
		elevator_zone.zone_status_changed.connect(_on_zone_status_changed)
		elevator_zone.player_entered.connect(_on_player_entered_zone)
	
	# NEW: Connect the button's signal
	if button:
		button.button_pressed_and_validated.connect(_on_button_pressed_and_validated)
		print("[Elevator] Connected to button signal")
	
	# Physics only runs during gate close + ascent
	set_physics_process(false)
	
	print("[Elevator] Initialized")


# NEW: This function receives the button press + validation result
func _on_button_pressed_and_validated(is_valid: bool, enemy_count: int, has_player: bool) -> void:
	print("[Elevator] Button pressed → Validation: ", "VALID" if is_valid else "INVALID")

	if is_departed:
		print("[Elevator] Already departed — ignoring button press")
		return

	# Check if valves are complete (for pacifist route)
	_check_valves_complete()

	if is_valid:
		print("[Elevator] Zone valid → starting departure (gate closing + rise)")
		start_departure()
	else:
		# Optional: give feedback why it failed
		if not has_player: print("[Elevator] Cannot depart — player not in zone")
		else: print("[Elevator] Cannot depart — ", enemy_count, " enemies still inside")

func _check_valves_complete() -> void:
	for node in get_tree().get_nodes_in_group("level2_puzzle"):
		if node.has_method("are_all_valves_complete"):
			valves_complete = node.are_all_valves_complete()
			if valves_complete:
				print("[Elevator] Valves complete - pacifist route!")
			return


# Original zone status signal handler
func _on_zone_status_changed(is_valid: bool, enemy_count: int) -> void:
	print("[Elevator] Zone status changed: ", "VALID" if is_valid else "INVALID", " (", enemy_count, " enemies)")
	if is_valid and auto_depart_on_valid and not is_departed:
		print("[Elevator] Auto-departure triggered")
		start_departure()

func _on_player_entered_zone() -> void:
	print("[Elevator] Player entered elevator zone")

# Starts gate closing -> then ascent
func start_departure() -> void:
	if is_departed:
		print("[Elevator] Already departed")
		return

	# Final safety check - bypass if valves complete (pacifist route)
	if not valves_complete:
		if not elevator_zone or not elevator_zone.is_zone_valid():
			print("[Elevator] Final check failed - zone invalid")
			return
	else:
		print("[Elevator] Bypassing enemy check - valves complete!")

	is_departed = true
	gate_closing = true
	can_rise = true
	set_physics_process(true)   # ← this enables _physics_process → door closes + elevator rises

	print("[Elevator] Departure sequence initiated")


# --- Physics (Gate close → Ascent) ---
func _physics_process(delta: float) -> void:
	# 1. Close the gate first (moving UP instead of down)
	if gate_closing and gate and gate.position.y < initial_gate_position.y + 3.0:
		gate.position.y += gate_speed * delta
		
		if gate.position.y >= initial_gate_position.y + 3.0:
			gate.position.y = initial_gate_position.y + 3.0
			gate_closing = false
			print("[Elevator] Gate fully closed")
	
	# 2. Rise the elevator (after gate is closed or simultaneously)
	if can_rise and global_position.y < target_height:
		global_position.y += speed * delta
	
	if global_position.y >= target_height:
		set_physics_process(false)
		print("[Elevator] Reached target height!")
		_on_arrival()


func _on_arrival() -> void:
	print("[Elevator] Arrival complete")
	# Add post-arrival logic here (e.g. open gate again, despawn enemies, etc.)

# Optional: manual trigger
func validate_and_depart() -> void:
	if elevator_zone and elevator_zone.is_zone_valid():
		start_departure()
	else:
		print("[Elevator] Validation failed - cannot depart")

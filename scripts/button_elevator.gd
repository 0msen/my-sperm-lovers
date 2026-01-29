extends Node3D
## Interactive elevator button that validates the elevator zone
## Changes light color based on validation result (green = valid, red = invalid)

# Node References
@onready var light: OmniLight3D = $OmniLight3D
@onready var interact_area: Area3D = $InteractableArea

# State
var player_in_range: bool = false
var elevator_zone: Area3D = null
var level2_puzzle: Node = null  # Reference to Level2Puzzle controller

# Signal for parent / other nodes to react when button is pressed + validation result
signal button_pressed_and_validated(is_valid: bool, enemy_count: int, has_player: bool)

func _ready() -> void:
	add_to_group("elevator_button")

	if interact_area:
		interact_area.body_entered.connect(_on_interact_area_entered)
		interact_area.body_exited.connect(_on_interact_area_exited)

	_find_elevator_zone()
	_set_light_color(false)  # start invalid/red

	# Defer finding puzzle to ensure it's initialized first
	await get_tree().process_frame
	await get_tree().process_frame
	_find_level2_puzzle()

	print("[ElevatorButton] Initialized at ", global_position)

func _find_level2_puzzle() -> void:
	# Find Level2Puzzle controller in scene
	for node in get_tree().get_nodes_in_group("level2_puzzle"):
		level2_puzzle = node
		print("[ElevatorButton] Found Level2Puzzle controller")
		return
	# Also try finding by script type
	var puzzles = get_tree().current_scene.find_children("*", "Node")
	for node in puzzles:
		if node.has_method("are_all_valves_complete"):
			level2_puzzle = node
			print("[ElevatorButton] Found Level2Puzzle controller by method")
			return

func _find_elevator_zone() -> void:
	var zones = get_tree().get_nodes_in_group("elevator_zone")
	if zones.size() > 0:
		elevator_zone = zones[0] as Area3D
		print("[ElevatorButton] Found elevator zone: ", elevator_zone.name)
	else:
		push_warning("[ElevatorButton] No elevator zone found in scene!")

func _on_interact_area_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		print("[ElevatorButton] Player entered interaction range")

func _on_interact_area_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		print("[ElevatorButton] Player left interaction range")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and player_in_range:
		_on_button_pressed()

func _on_button_pressed() -> void:
	print("[ElevatorButton] Button pressed!")

	if not elevator_zone:
		_find_elevator_zone()

	if not elevator_zone:
		print("[ElevatorButton] ERROR: No elevator zone found!")
		_set_light_color(false)
		button_pressed_and_validated.emit(false, 0, false)
		return

	var has_player = elevator_zone.has_player()
	var enemy_count = elevator_zone.get_enemy_count()

	# Check if all valves are complete (pacifist route)
	var valves_complete = false
	if level2_puzzle and level2_puzzle.has_method("are_all_valves_complete"):
		valves_complete = level2_puzzle.are_all_valves_complete()

	# Validation: Player must be present
	# If valves complete: enemies don't matter
	# If valves not complete: no enemies allowed
	var is_valid = false
	if has_player:
		if valves_complete:
			is_valid = true
			print("[ElevatorButton] All valves complete - bypassing enemy check!")
		else:
			is_valid = (enemy_count == 0)

	_set_light_color(is_valid)
	button_pressed_and_validated.emit(is_valid, enemy_count, has_player)

	if is_valid:
		print("[ElevatorButton] ✓ VALID - Elevator ready!")
	else:
		if not has_player:
			print("[ElevatorButton] ✗ FAILED - No player in zone")
		else:
			print("[ElevatorButton] ✗ FAILED - ", enemy_count, " enemies in zone (complete valves to bypass)")

func _set_light_color(is_valid: bool) -> void:
	if not light: return
	
	if is_valid:
		light.light_color = Color("#00ff00")  # Green
		print("[ElevatorButton] Light → GREEN")
	else:
		light.light_color = Color("#ff0000")  # Red
		print("[ElevatorButton] Light → RED")

## Optional: can be called externally (e.g. via signal) to re-check without pressing
func validate_zone() -> void:
	if elevator_zone:
		var is_valid = elevator_zone.validate()
		_set_light_color(is_valid)

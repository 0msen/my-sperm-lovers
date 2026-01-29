extends Node

## Level 2 Puzzle Controller
## Tracks valve completion and controls sperm behavior

signal all_valves_completed
signal valve_activated(valve_position: Vector3)
signal valve_deactivated

# --- State ---
var completed_valves: int = 0
var total_valves: int = 3
var all_complete: bool = false
var active_valve: Node3D = null  # Currently active valve (being used)

# --- References ---
var valves: Array[Node] = []
var sperms: Array[Node] = []

func _ready() -> void:
	add_to_group("level2_puzzle")

	# Find all valves in scene after a frame
	await get_tree().process_frame
	_find_and_connect_valves()

func _find_and_connect_valves() -> void:
	valves = []
	for valve in get_tree().get_nodes_in_group("valves"):
		valves.append(valve)
		valve.valve_completed.connect(_on_valve_completed.bind(valve))
		valve.valve_started.connect(_on_valve_started.bind(valve))
		valve.valve_stopped.connect(_on_valve_stopped.bind(valve))

	total_valves = valves.size()
	print("[Level2Puzzle] Found ", total_valves, " valves")

func _on_valve_completed(valve: Node) -> void:
	completed_valves += 1
	print("[Level2Puzzle] Valve completed! ", completed_valves, "/", total_valves)

	if completed_valves >= total_valves:
		all_complete = true
		all_valves_completed.emit()
		print("[Level2Puzzle] ALL VALVES COMPLETE - Button now usable!")

func _on_valve_started(valve: Node) -> void:
	active_valve = valve
	valve_activated.emit(valve.global_position)

	# Notify all sperms about active valve
	_notify_sperms_valve_active(valve.global_position)

func _on_valve_stopped(valve: Node) -> void:
	if active_valve == valve:
		active_valve = null
		valve_deactivated.emit()

		# Notify sperms valve is no longer active
		_notify_sperms_valve_inactive()

func _notify_sperms_valve_active(valve_pos: Vector3) -> void:
	for sperm in get_tree().get_nodes_in_group("sperm"):
		if sperm.has_method("on_valve_activated"):
			sperm.on_valve_activated(valve_pos)

func _notify_sperms_valve_inactive() -> void:
	for sperm in get_tree().get_nodes_in_group("sperm"):
		if sperm.has_method("on_valve_deactivated"):
			sperm.on_valve_deactivated()

func are_all_valves_complete() -> bool:
	return all_complete

func get_active_valve_position() -> Vector3:
	if active_valve:
		return active_valve.global_position
	return Vector3.ZERO

func has_active_valve() -> bool:
	return active_valve != null

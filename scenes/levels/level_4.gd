extends Node3D

@onready var organs = {
	"red": get_node("RedOrgan"),
	"blue": get_node("BlueOrgan"),
	"green": get_node("GreenOrgan"),
	"yellow": get_node("YellowOrgan")
}
@onready var fuse_box: StaticBody3D = $FuseBox

var current_sequence = []
var player_sequence = []
var current_round = 0
var is_showing_sequence = false
var is_player_turn = false
var game_ended: bool = false  # True if door opened (by puzzle OR violence)

func _ready():
	# Initialize all organs to show normal, hide glow
	for organ_name in organs.keys():
		var organ = organs[organ_name]
		var normal_mesh = organ.get_node("Normal")
		var glow_mesh = organ.get_node("Glow")
		
		normal_mesh.visible = true
		glow_mesh.visible = false
	
	# Connect fuse box destruction signal
	if fuse_box:
		fuse_box.destroyed.connect(_on_fuse_box_destroyed)
	
	print("Simon Says initialized!")
	await get_tree().create_timer(1.0).timeout
	start_game()

func glow_organ(color: String):
	var organ = organs[color]
	var normal_mesh = organ.get_node("Normal")
	var glow_mesh = organ.get_node("Glow")
	
	normal_mesh.visible = false
	glow_mesh.visible = true
	
	var tween = create_tween()
	tween.tween_property(organ, "scale", Vector3(1.15, 1.15, 1.15), 0.15)

func unglow_organ(color: String):
	var organ = organs[color]
	var normal_mesh = organ.get_node("Normal")
	var glow_mesh = organ.get_node("Glow")
	
	normal_mesh.visible = true
	glow_mesh.visible = false
	
	var tween = create_tween()
	tween.tween_property(organ, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

# Connect these functions to each Area3D's input_event signal
func _on_red_area_input_event(camera, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("red")

func _on_blue_area_input_event(camera, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("blue")

func _on_green_area_input_event(camera, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("green")

func _on_yellow_area_input_event(camera, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("yellow")

func start_game():
	current_round = 1
	current_sequence = []
	show_doorethy_dialogue("Alright, let's see if you have ANY culture. Watch closely, peasant.")
	await get_tree().create_timer(2.0).timeout
	next_round()

func next_round():
	is_player_turn = false
	player_sequence = []
	
	var colors = ["red", "blue", "green", "yellow"]
	current_sequence.append(colors[randi() % colors.size()])
	
	show_doorethy_dialogue("Round %d. Try to keep up." % current_round)
	await get_tree().create_timer(1.5).timeout
	
	show_sequence()

func show_sequence():
	is_showing_sequence = true
	
	for color in current_sequence:
		glow_organ(color)
		await get_tree().create_timer(0.8).timeout
		unglow_organ(color)
		await get_tree().create_timer(0.4).timeout
	
	is_showing_sequence = false
	is_player_turn = true
	show_doorethy_dialogue("Your turn. Don't embarrass yourself.")

func check_input(color: String):
	# Critical FIX: Don't process input if not in player turn, showing sequence, or game is over
	if not is_player_turn or is_showing_sequence or current_round > 10 or game_ended:
		print("Input ignored - not player's turn or game over")
		return
	
	print("Player selected: ", color)
	
	glow_organ(color)
	await get_tree().create_timer(0.3).timeout
	unglow_organ(color)
	
	player_sequence.append(color)
	# Safety FIX: Prevent out-of-bounds access, player can spam buzz
	var step = player_sequence.size() - 1
	if step >= current_sequence.size():
		print("Warning: Player clicked too many times!")
		return
		
	if color != current_sequence[step]:
		# Implies, player made a mistake, thus, Immediately stop accepting input
		is_player_turn = false  
		if current_round == 9:
			show_doorethy_dialogue("HAHAHAHA! You were SO CLOSE! Round 9! Back to Round 1, loser!")
		else:
			show_doorethy_dialogue("WRONG! Start over, nerd.")
		await get_tree().create_timer(2.0).timeout
		reset_game()
		return
	
	if player_sequence.size() == current_sequence.size():
		# Implies, player won, thus, no need to ask for user input
		is_player_turn = false
		
		# Reward patience with karma (+5 per round completed)
		if GameManager:
			GameManager.add_karma_xp(5.0)
		
		if current_round == 10:
			show_doorethy_dialogue("Ugh... FINE. I suppose you ARE cultured. You may pass.")
			await get_tree().create_timer(2.0).timeout
			open_door()
		else:
			current_round += 1
			show_doorethy_dialogue("Wow, look at you following rules. Good puppy.")
			await get_tree().create_timer(1.5).timeout
			next_round()

func reset_game():
	current_round = 1
	current_sequence = []
	player_sequence = []
	await get_tree().create_timer(1.0).timeout
	next_round()

func show_doorethy_dialogue(text: String):
	print("Doorethy: ", text)

func open_door():
	if game_ended:
		return
	game_ended = true
	print("Door opens! You win!")

# === VIOLENCE PATH: Fuse Box Destruction ===
func _on_fuse_box_destroyed() -> void:
	if game_ended:
		return
	
	# Stop the Simon Says game immediately
	is_player_turn = false
	is_showing_sequence = false
	
	# Doorethy's anguished response
	show_doorethy_dialogue("AAAAARGH!! MY HEART! YOU... YOU MONSTER!")
	await get_tree().create_timer(1.5).timeout
	show_doorethy_dialogue("You could have just played the game... but NO... you chose VIOLENCE!")
	await get_tree().create_timer(2.0).timeout
	show_doorethy_dialogue("Fine! FINE! The door is open! I hope you're HAPPY, you BRUTE!")
	await get_tree().create_timer(1.5).timeout
	
	# Force the door open
	open_door_violently()

func open_door_violently():
	game_ended = true
	print("Door FORCED open through violence!")
	# TODO: Add door slam animation, sparks, etc.

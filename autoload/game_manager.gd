extends Node

signal karma_updated(level: int, progress: float, is_positive: bool)

const XP_PER_LEVEL: float = 100.0

var raw_karma: float = 0.0

# Music system
var aggro_enemy_count: int = 0
var default_music: AudioStreamPlayer
var aggro_music: AudioStreamPlayer


func _ready() -> void:
	_setup_music()


func _setup_music() -> void:
	default_music = AudioStreamPlayer.new()
	default_music.stream = preload("res://sounds/defaultBG.mp3")
	default_music.bus = "Master"
	default_music.autoplay = true
	add_child(default_music)
	default_music.finished.connect(_on_default_music_finished)

	aggro_music = AudioStreamPlayer.new()
	aggro_music.stream = preload("res://sounds/enemyAggroBG.mp3")
	aggro_music.bus = "Master"
	add_child(aggro_music)
	aggro_music.finished.connect(_on_aggro_music_finished)


func on_enemy_aggro() -> void:
	aggro_enemy_count += 1
	if aggro_enemy_count == 1:
		_switch_to_aggro_music()


func on_enemy_died() -> void:
	aggro_enemy_count = max(0, aggro_enemy_count - 1)
	if aggro_enemy_count == 0:
		_switch_to_default_music()


func _switch_to_aggro_music() -> void:
	default_music.stop()
	aggro_music.play()


func _switch_to_default_music() -> void:
	aggro_music.stop()
	default_music.play()


func _on_default_music_finished() -> void:
	if aggro_enemy_count == 0:
		default_music.play()


func _on_aggro_music_finished() -> void:
	if aggro_enemy_count > 0:
		aggro_music.play()


func add_karma_xp(amount: float) -> void:
	raw_karma += amount / XP_PER_LEVEL
	var level = get_karma_level()
	var progress = get_karma_progress()
	var is_positive = raw_karma >= 0.0
	print("[GameManager] Karma XP: ", amount, " | Raw: ", raw_karma, " | Level: ", level, " | Progress: ", progress)
	karma_updated.emit(level, progress, is_positive)

# Added a function, exclusive for the dialog system only
func get_karma_level_DialogSystem() -> float:
	return raw_karma

# Wont try to edit this
func get_karma_level() -> int:
	if raw_karma >= 0.0:
		return int(floor(raw_karma))
	else:
		return int(ceil(raw_karma))


func get_karma_progress() -> float:
	var level = get_karma_level()
	return abs(raw_karma - float(level))


func reset_karma() -> void:
	raw_karma = 0.0
	karma_updated.emit(0, 0.0, true)

extends Control

@onready var text_label: RichTextLabel = $TextLabel
@onready var typing_sound: AudioStreamPlayer = $typing_sound

var typing_speed := 0.03
var is_typing := false

func type_text(text: String) -> void:
	is_typing = true
	text_label.text = ""

	for char in text:
		text_label.text += char

		if char != " " and char != "\n":
			typing_sound.pitch_scale = randf_range(0.95, 1.05)
			typing_sound.play()

		await get_tree().create_timer(typing_speed).timeout

	is_typing = false

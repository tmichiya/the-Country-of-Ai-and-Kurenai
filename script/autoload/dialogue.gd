extends Node2D

signal started
signal finished

enum Style {
	NORMAL,
	SHOUT,
	WHISPER
}

var WHITE: Color = Color(1, 1, 1)
var RED: Color = Color(0.89, 0.116, 0.089)

var BIG_TEXT_SIZE = 12
var NORMAL_TEXT_SIZE = 10
var SMALL_TEXT_SIZE = 8

var shake_strength: float = 0.0
var shake_decay: float = 5.0

var displaying_speed: float = 0.03

var is_displaying: bool = false

var conversations: Dictionary

var speakers: Dictionary = {}

class Line:
	var text: String
	var style: Style
	var speaker: Node2D
	var text_color: Color
	var text_size: int
	var camera_target: CharacterBody2D
	func _init(_speaker: Node2D, _style: Style, _text: String, _text_color: Color = Color(-1,-1,-1), _text_size: int = -1, _camera_target: CharacterBody2D = null) -> void:
		text = _text
		style = _style
		speaker = _speaker
		text_color = _text_color
		text_size = _text_size
		if camera_target == null:
			camera_target = _speaker
		else:
			camera_target = _camera_target

@onready var canvas: CanvasLayer = $CanvasLayer
@onready var chat_control: Control = $CanvasLayer/Chat
@onready var label: Label = $CanvasLayer/Chat/PanelContainer/MarginContainer/Label

# === say system ===

func say(lines: Array[Line]) -> void:
	started.emit()
	is_displaying = true
	canvas.visible = true
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	for line in lines:
		await _display_line(line)
	canvas.visible = false
	is_displaying = false
	finished.emit()

func _display_line(line: Line) -> void:
	label.text = line.text
	_set_label_style(line)
	label.visible_ratio = 0.0
	var tw = create_tween()
	tw.tween_property(label, "visible_ratio", 1.0,  line.text.length() * displaying_speed)
	
	while tw.is_running():
		if Input.is_action_just_pressed("ui_accept"):
			tw.kill()
			label.visible_ratio = 1.0
		chat_control.position = _get_screen_position(line.speaker)
		Camera.set_current_target(line.camera_target.name)
		await get_tree().process_frame
	
	await _wait_for_advance(line.speaker)

func _set_label_style(line: Line) -> void:
	match line.style:
		Style.NORMAL:
			displaying_speed = 0.03
			label.add_theme_color_override("font_color", WHITE)
			label.add_theme_font_size_override("font_size", NORMAL_TEXT_SIZE)
		Style.SHOUT:
			shake(5.0)
			displaying_speed = 0.006
			label.add_theme_color_override("font_color", RED)
			label.add_theme_font_size_override("font_size", BIG_TEXT_SIZE)
		Style.WHISPER:
			displaying_speed = 0.02
			label.add_theme_color_override("font_color", WHITE)
			label.add_theme_font_size_override("font_size", SMALL_TEXT_SIZE)
	if line.text_color != Color(-1,-1,-1):
		label.add_theme_color_override("font_color", line.text_color)
	if line.text_size != -1:
		label.add_theme_font_size_override("font_size", line.text_size)

func _wait_for_advance(target: Node2D) -> void:
	await get_tree().process_frame
	while not Input.is_action_just_pressed("ui_accept"):
		chat_control.position = _get_screen_position(target)
		await get_tree().process_frame

func shake(strength: float) -> void:
	shake_strength = max(shake_strength, strength)

func _get_screen_position(target: Node2D) -> Vector2:
	var viewport = target.get_viewport()
	var target_position: Vector2 = viewport.get_canvas_transform() * target.get_global_transform().origin
	return target_position

# === load json file ===
func load_json(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: %s" % file_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Failed to parse JSON data from file: %s" % file_path)
		return
	conversations = data

# === play a conversation ===
func play_conversation(conversation_tag: String) -> void:
	print("play_conversation: %s" % conversation_tag)
	if not conversations.has(conversation_tag):
		push_error("Conversation tag not found: %s" % conversation_tag)
		return
	var lines_data = conversations[conversation_tag]
	var lines: Array[Line] = []
	for line_data in lines_data:
		var speaker : CharacterBody2D = speakers.get(line_data["speaker"], null)

		var style = Style.NORMAL
		match line_data["style"]:
			"NORMAL":
				style = Style.NORMAL
			"SHOUT":
				style = Style.SHOUT
			"WHISPER":
				style = Style.WHISPER
		
		var text_color = Color(-1, -1, -1)
		if line_data.has("text_color") and line_data["text_color"] != "":
			var text_color_str = line_data["text_color"]
			if text_color_str == "WHITE":
				text_color = WHITE
			elif text_color_str == "RED":
				text_color = RED
			else:
				text_color = Color(line_data["text_color"])
		
		var text_size = -1
		if line_data.has("text_size") and line_data["text_size"] != "":
			text_size = int(line_data["text_size"])
		
		var camera_target: CharacterBody2D = speaker
		if line_data.has("camera_target"):
			camera_target = speakers.get(line_data["camera_target"], null)

		lines.append(Line.new(speaker, style, line_data["text"], text_color, text_size, camera_target))

	if speakers.keys().size() == 0:
		push_error("No speakers have been registered. Please register speakers before playing a conversation.")
		return
	print("speakers: %s" % speakers.keys())
	await say(lines)

# === modify data ===
func reset_speakers() -> void:
	speakers.clear()

func add_speaker(name: String, speaker_node: Node2D) -> void:
	speakers[name] = speaker_node

func _ready() -> void:
	is_displaying = false
	load_json("res://chat_line/chat_lines.json")

func _process(delta: float) -> void:
	# shake effect
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		if chat_control.offset_transform_enabled:
			chat_control.offset_transform_position = Vector2(
				randf_range(-shake_strength, shake_strength), 
				randf_range(-shake_strength, shake_strength)
			)

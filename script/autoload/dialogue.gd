extends Node

signal started(tag: String)
signal finished(tag: String)

signal loop0_post_aura
signal loop0_post_end
signal loop1_post_aura
signal loop1_post_end

enum Style {
	NORMAL,
	SHOUT,
	WHISPER
}

var WHITE: Color = Color(1, 1, 1)
var RED: Color = Color(0.89, 0.116, 0.089)

var BIG_TEXT_SIZE = 16
var NORMAL_TEXT_SIZE = 8
var SMALL_TEXT_SIZE = 6

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
	var text_speed: float
	var camera_target: String
	var box_style: String = "normal"
	var box_side: String = "right"
	var signal_name: String = ""
	func _init(_speaker: Node2D, _style: Style, _text: String, _text_color: Color = Color(-1,-1,-1), _text_size: int = -1, _text_speed: float = -1.0, _camera_target: String = "", _box_style: String = "", _box_side: String = "right", _signal_name: String = "") -> void:
		text = _text
		style = _style
		speaker = _speaker
		text_color = _text_color
		text_size = _text_size
		text_speed = _text_speed
		camera_target = _camera_target
		if _box_style:
			box_style = _box_style
		if _box_side:
			box_side = _box_side
		if _signal_name:
			signal_name = _signal_name

@onready var canvas: CanvasLayer = $CanvasLayer
@onready var chat_control: Control = $CanvasLayer/CenterContainer/Chat
@onready var label: Label = $CanvasLayer/CenterContainer/Chat/PanelContainer/MarginContainer/Label
@onready var panel_container: PanelContainer = $CanvasLayer/CenterContainer/Chat/PanelContainer

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var chat_box_style_normal: StyleBoxTexture
@export var chat_box_style_tele: StyleBoxTexture

# === say system ===

func say(tag: String, lines: Array[Line]) -> void:
	var current_camera_state = Camera.state
	var current_camera_target = Camera.current_target

	started.emit(tag)
	is_displaying = true
	canvas.visible = true
	# Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	for line in lines:
		await _display_line(line)
	canvas.visible = false
	is_displaying = false

	Camera.state = current_camera_state
	Camera.set_current_target(current_camera_target)

	finished.emit(tag)

func _display_line(line: Line) -> void:
	label.text = line.text
	panel_container.reset_size()
	label.visible_ratio = 0.0

	_set_label_style(line)
	_set_chat_box_style(line.box_style)
	_set_chat_box_side(line.box_side)
	_play_chat_box_animation(line.box_side)
	_set_displaying_speed(line.text_speed)

	if line.camera_target != "":
		Camera.state = Camera.CameraState.FOLLOW_TARGET
		Camera.set_current_target(line.camera_target)
	else:
		Camera.state = Camera.CameraState.AVERAGE_CENTER

	if line.signal_name != "":
		if has_signal(line.signal_name):
			emit_signal(line.signal_name)
		else:
			push_error("Signal '%s' does not exist in Dialogue.gd" % line.signal_name)

	await get_tree().process_frame

	var tw = create_tween()
	tw.tween_property(label, "visible_ratio", 1.0,  line.text.length() * displaying_speed)
	
	while tw.is_running():
		if  Input.is_action_just_pressed("ui_accept"):
			tw.kill()
			label.visible_ratio = 1.0
		chat_control.position = _get_screen_position(line.speaker)
		await get_tree().process_frame
	
	await _wait_for_advance(line.speaker)

func _set_label_style(line: Line) -> void:
	match line.style:
		Style.NORMAL:
			displaying_speed = 0.03
			label.modulate.a = 1.0
			label.add_theme_color_override("font_color", WHITE)
			label.add_theme_font_size_override("font_size", NORMAL_TEXT_SIZE)
		Style.SHOUT:
			Effects.shake(2.0)
			displaying_speed = 0.006
			label.modulate.a = 1.0
			label.add_theme_color_override("font_color", RED)
			label.add_theme_font_size_override("font_size", BIG_TEXT_SIZE)
		Style.WHISPER:
			displaying_speed = 0.02
			label.modulate.a = 0.5
			label.add_theme_color_override("font_color", WHITE)
			label.add_theme_font_size_override("font_size", SMALL_TEXT_SIZE)
	if line.text_color != Color(-1,-1,-1):
		label.add_theme_color_override("font_color", line.text_color)
	if line.text_size != -1:
		label.add_theme_font_size_override("font_size", line.text_size)

func _set_chat_box_style(box_style: String) -> void:
	match box_style:
		"normal":
			panel_container.add_theme_stylebox_override("panel", chat_box_style_normal)
		"tele":
			panel_container.add_theme_stylebox_override("panel", chat_box_style_tele)

func _set_chat_box_side(box_side: String) -> void:
	match box_side:
		"left":
			panel_container.position.x = 0
			panel_container.position.x -= panel_container.size.x
		"right":
			panel_container.position.x = 0
			chat_control.offset_transform_position.x = 25

func _play_chat_box_animation(box_side: String) -> void:
	match box_side:
		"left":
			animation_player.play("show_chat_box_left")
		"right":
			animation_player.play("show_chat_box_right")

func _set_displaying_speed(text_speed: float) -> void:
	if text_speed != -1.0:
		displaying_speed = text_speed

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

# !!! debug 用に変更中 !!!

func load_battle_json() -> void:
	load_json("res://chat_line/battle_chat_lines.json")

func load_campfire_json() -> void:
	load_json("res://chat_line/campfire_chat_lines.json")

func load_opening_json() -> void:
	load_json("res://chat_line/test/opening_chat_lines.json")

func load_death_json() -> void:
	load_json("res://chat_line/test/death_chat_lines.json")

func load_ending_json() -> void:
	load_json("res://chat_line/ending_chat_lines.json")

# === construct and play a conversation ===
func play_conversation(conversation_tag: String) -> void:
	if not conversations.has(conversation_tag):
		push_error("Conversation tag not found: %s" % conversation_tag)
		return
	var lines_data = conversations[conversation_tag]
	var lines: Array[Line] = []
	for line_data in lines_data:
		var speaker : Node2D = speakers.get(line_data["speaker"], null)

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
		if line_data.has("text_size") and line_data["text_size"] != -1:
			text_size = int(line_data["text_size"])
		
		var camera_target: String = ""
		print("Processing line data: %s" % line_data)
		if line_data.has("camera_target"):
			print("Camera target found in line data: %s" % line_data["camera_target"])
			camera_target = line_data["camera_target"]

		var box_style: String = "normal"
		if line_data.has("box_style"):
			box_style = line_data["box_style"]

		var box_side: String = "right"
		if line_data.has("box_side"):
			box_side = line_data["box_side"]

		var text_speed: float = -1.0
		if line_data.has("text_speed"):
			text_speed = float(line_data["text_speed"])

		var signal_name: String = ""
		if line_data.has("signal"):
			signal_name = line_data["signal"]

		lines.append(Line.new(speaker, style, line_data["text"], text_color, text_size, text_speed, camera_target, box_style, box_side, signal_name))

	if speakers.keys().size() == 0:
		push_error("No speakers have been registered. Please register speakers before playing a conversation.")
		return
	await say(conversation_tag, lines)

# === modify data ===
func reset_speakers() -> void:
	speakers.clear()

func add_speaker(name: String, speaker_node: Node2D) -> void:
	speakers[name] = speaker_node

func _ready() -> void:
	is_displaying = false
	canvas.visible = false

func _process(delta: float) -> void:
	# shake effect
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		if chat_control.offset_transform_enabled:
			chat_control.offset_transform_position = Vector2(
				randf_range(-shake_strength, shake_strength), 
				randf_range(-shake_strength, shake_strength)
			)

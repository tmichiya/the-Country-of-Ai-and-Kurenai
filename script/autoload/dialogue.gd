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

class Line:
	var text: String
	var style: Style
	var speaker: Node2D
	var text_color: Color
	var text_size: int
	func _init(_speaker: Node2D, _style: Style, _text: String, _text_color: Color = Color(-1,-1,-1), _text_size: int = -1) -> void:
		text = _text
		style = _style
		speaker = _speaker
		text_color = _text_color
		text_size = _text_size

@onready var canvas: CanvasLayer = $CanvasLayer
@onready var chat_control: Control = $CanvasLayer/Chat
@onready var label: Label = $CanvasLayer/Chat/PanelContainer/MarginContainer/Label


#debug
@onready var test: Node2D = $test

func say(lines: Array[Line]) -> void:
	started.emit()
	is_displaying = true
	canvas.visible = true
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
		await get_tree().process_frame
	
	await _wait_for_advance(line.speaker)

func _set_label_style(line: Line) -> void:
	match line.style:
		Style.NORMAL:
			displaying_speed = 0.03
			label.add_theme_color_override("font_color", WHITE)
			label.add_theme_font_size_override("font_size", NORMAL_TEXT_SIZE)
		Style.SHOUT:
			shake(3.0)
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_displaying = false


func _get_screen_position(target: Node2D) -> Vector2:
	var viewport = target.get_viewport()
	var target_position: Vector2 = viewport.get_screen_transform() * target.get_global_transform().origin
	return target_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# shake effect
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		if chat_control.offset_transform_enabled:
			chat_control.offset_transform_position = Vector2(
				randf_range(-shake_strength, shake_strength), 
				randf_range(-shake_strength, shake_strength)
			)

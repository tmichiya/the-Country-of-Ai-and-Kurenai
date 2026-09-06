extends Node

signal started(tag: String)
signal finished(tag: String)
## 会話が最後まで行かずに打ち切られた（部屋の切り替えなど）。
## finished とは区別する。finished を「会話をやり切った合図」として
## 使っている側（戦闘開始など）が、中断で誤発火しないようにするため。
signal cancelled(tag: String)

# --- 長押しスキップ用（見た目はゲーム側で自由に作れるよう、状態だけ配信する） ---
## 長押しが始まった
signal skip_hold_started
## 長押し中の進捗 0.0〜1.0。毎フレーム飛ぶ。ゲージの見た目はこれを購読して作る
signal skip_hold_progress(ratio: float)
## 長押しを途中で離した
signal skip_hold_cancelled
## スキップが成立して会話ブロックを飛ばした
signal skipped(tag: String)

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
var WHITE_BLUE: Color = Color(0.459, 0.62, 0.996)
var WHILE_RED: Color = Color(1.0, 0.46, 0.46)

## 話者ごとの文字色。**キーは JSON の "speaker" の値**（＝ add_speaker() で登録した id）で、
## シーン上のノード名ではない。ノード名はエディタで自由に変えられてしまうので、
## 会話データ側の id を正とするほうが壊れにくい。
## 話者を増やしたいときはここに1行足すだけでよい。
var SPEAKER_TEXT_COLORS: Dictionary = {
	"statue": WHILE_RED,
	"player": WHITE_BLUE,   # ← 通信ボイスを青くしたい場合はこれを有効化
}

var BIG_TEXT_SIZE = 16
var NORMAL_TEXT_SIZE = 8
var SMALL_TEXT_SIZE = 6

var shake_strength: float = 0.0
var shake_decay: float = 5.0

var displaying_speed: float = 0.03

var is_displaying: bool = false

var conversations: Dictionary

var speakers: Dictionary = {}

## いま流している会話のタグ（流していなければ ""）
var current_tag: String = ""

# --- 長押しスキップ ---
## 何秒押しっぱなしでスキップ成立にするか
@export var skip_hold_seconds: float = 2.0
## 会話ごとにスキップ可否を切り替えたいとき用（play_conversation の引数でも指定できる）
var skip_enabled: bool = true

var _skip_hold: float = 0.0
var _skip_requested: bool = false
## 前の会話から押しっぱなしのまま次の会話に入って即スキップ、を防ぐためのラッチ。
## 一度キーを離すまで長押し計測を始めない。
var _skip_latched: bool = false
## 中断要求（room 切り替えなど外部からの打ち切り）
var _abort_requested: bool = false
## 「いま走っている say() は何世代目か」。会話を打ち切ったり別の会話を始めたときに
## 増やして、古い say() のループが自分は用済みだと気づけるようにする。
var _generation: int = 0

class Line:
	var text: String
	var style: Style
	var speaker: Node2D
	## 会話データ上の話者 id（"player" / "hakubo" / "statue" …）。
	## speaker（ノード）の name はシーン上の名前（"Player" など）で別物なので、
	## 「誰が喋っているか」で分岐したいときは必ずこちらを見る。
	var speaker_id: String
	var text_color: Color
	var text_size: int
	var text_speed: float
	var camera_target: String
	var box_style: String = "normal"
	var box_side: String = "right"
	var signal_name: String = ""
	func _init(_speaker: Node2D, _speaker_id: String, _style: Style, _text: String, _text_color: Color = Color(-1,-1,-1), _text_size: int = -1, _text_speed: float = -1.0, _camera_target: String = "", _box_style: String = "", _box_side: String = "right", _signal_name: String = "") -> void:
		text = _text
		style = _style
		speaker = _speaker
		speaker_id = _speaker_id
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

@onready var skip_control: Control = $CanvasLayer/CenterContainer/Skip

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var chat_box_style_normal: StyleBoxTexture
@export var chat_box_style_tele: StyleBoxTexture

# === say system ===

func say(tag: String, lines: Array[Line]) -> void:
	var current_camera_state = Camera.state
	var current_camera_target = Camera.current_target

	_generation += 1
	var my_generation := _generation

	current_tag = tag
	_skip_requested = false
	_abort_requested = false
	_skip_hold = 0.0
	# 直前のキー入力を引きずってすぐスキップされないよう、
	# 一度離すまで長押し計測を始めない状態から入る。
	_skip_latched = Input.is_action_pressed("dialogue_skip")

	started.emit(tag)
	is_displaying = true
	canvas.visible = true

	var index := 0
	while index < lines.size():
		var line: Line = lines[index]
		if _abort_requested or _generation != my_generation:
			break
		if _skip_requested:
			break
		AudioManager.play_se("next_chat")
		await _display_line(line)
		index += 1

	# 自分より新しい会話が始まっていたら、画面やカメラには一切触らずに黙って降りる。
	# （触ると新しい会話のチャット枠を消してしまう）
	if _generation != my_generation:
		return

	var was_skipped := _skip_requested
	var was_aborted := _abort_requested

	# スキップで読み飛ばした行にも "signal" が仕込まれていることがある。
	# これはオーラを出す等ゲーム状態を進める合図なので、飛ばしたぶんも消化しておく。
	# （読み飛ばしただけで演出が永久に出なくなる、という取りこぼしを防ぐ）
	# 一方 abort（部屋の切り替え）は「この会話はなかったこと」にしたいので流さない。
	if was_skipped and index < lines.size():
		for i in range(index, lines.size()):
			_emit_line_signal(lines[i])

	canvas.visible = false
	is_displaying = false
	current_tag = ""
	_skip_hold = 0.0
	skip_hold_progress.emit(0.0)

	Camera.state = current_camera_state
	Camera.set_current_target(current_camera_target)

	if was_aborted:
		# 中断は「やり切った」ではないので finished は出さない
		cancelled.emit(tag)
		return

	if was_skipped:
		skipped.emit(tag)
	# スキップでも「その会話ブロックは終わった」ことに変わりはないので
	# finished は必ず出す。これがないと戦闘開始などの次の処理へ進めない。
	finished.emit(tag)


## 走っている会話を即座に打ち切る。部屋を切り替えるときに必ず呼ぶ。
## 呼ばないと、前の部屋が始めた会話が生き残って、
## 次の部屋のフラグ（戦闘開始など）を後から誤って進めてしまう。
func cancel() -> void:
	if not is_displaying:
		return
	_abort_requested = true


func get_skip_progress() -> float:
	if skip_hold_seconds <= 0.0:
		return 0.0
	return clampf(_skip_hold / skip_hold_seconds, 0.0, 1.0)


## 長押しスキップの進行。会話待ちのループから毎フレーム呼ぶ。
## true を返したらその会話ブロックを打ち切る。
func _tick_skip() -> bool:
	if _skip_requested or _abort_requested:
		return true
	if not skip_enabled or get_tree().paused:
		_release_skip_hold()
		return false

	var pressed := Input.is_action_pressed("dialogue_skip")

	# 会話をまたいで押しっぱなしだった場合、いったん離すまでは計測しない
	if _skip_latched:
		if not pressed:
			_skip_latched = false
		return false

	if pressed:
		if _skip_hold <= 0.0:
			skip_hold_started.emit()
			skip_control.play_skip_animation()
			Effects.smooth_shake(0.0, 4.0, 2.0)
		_skip_hold += get_process_delta_time()
		skip_hold_progress.emit(get_skip_progress())
		if _skip_hold >= skip_hold_seconds:
			_skip_requested = true
			return true
	else:
		_release_skip_hold()
		skip_control.stop_skip_animation()
		Effects.shake(0.0)
		Effects.kill_smooth_shake()
	return false


func _release_skip_hold() -> void:
	if _skip_hold > 0.0:
		_skip_hold = 0.0
		skip_hold_cancelled.emit()
		skip_hold_progress.emit(0.0)


func _emit_line_signal(line: Line) -> void:
	if line.signal_name == "":
		return
	if has_signal(line.signal_name):
		emit_signal(line.signal_name)
	else:
		push_error("Signal '%s' does not exist in Dialogue.gd" % line.signal_name)

func _display_line(line: Line) -> void:
	label.text = line.text
	panel_container.reset_size()
	label.visible_ratio = 0.0

	_set_label_style(line)
	_apply_label_color(line)     # 色は style を土台にして上書きするので、必ず _set_label_style の後
	_set_chat_box_style(line.box_style)
	_set_chat_box_side(line.box_side)
	_play_chat_box_animation(line.box_side)
	_set_displaying_speed(line.text_speed)

	if line.camera_target != "":
		Camera.state = Camera.CameraState.FOLLOW_TARGET
		Camera.set_current_target(line.camera_target)
	else:
		Camera.state = Camera.CameraState.AVERAGE_CENTER

	_emit_line_signal(line)

	await get_tree().process_frame

	var tw = create_tween()
	tw.tween_property(label, "visible_ratio", 1.0,  line.text.length() * displaying_speed)

	while tw.is_running():
		if _tick_skip():
			tw.kill()
			return
		if _advance_just_pressed():
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
	# 文字色の最終決定は _apply_label_color() に一本化してある（ここでは style の既定色だけ）。
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

## 文字色を決める。弱い順に上書きしていくので、下に書いたものほど優先される。
##   1. style ごとの既定色（_set_label_style が設定済み。NORMAL=白 / SHOUT=赤 / WHISPER=白）
##   2. 話者ごとの色（SPEAKER_TEXT_COLORS）
##   3. その行の "text_color"（1行だけの例外指定。最優先）
## SHOUT の赤を話者色より優先したい行があれば、その行に "text_color": "RED" を書けばよい。
func _apply_label_color(line: Line) -> void:
	if line.text_color != Color(-1, -1, -1):
		label.add_theme_color_override("font_color", line.text_color)
	elif SPEAKER_TEXT_COLORS.has(line.speaker_id):
		if line.box_style != "tele" and line.speaker_id == "player":  # 通信ボイスは青くしたい場合はこの条件を削除
			return
		label.add_theme_color_override("font_color", SPEAKER_TEXT_COLORS[line.speaker_id])

## 会話送りの入力判定。
## 【注意】会話待ちは `await get_tree().process_frame` のループで回っているが、
## process_frame は paused=true でも発火し続ける（＝ポーズの影響を受けない）。
## そのためポーズ中は明示的に入力を無視しないと、メニューを開いたまま会話が進んでしまう。
func _advance_just_pressed() -> bool:
	if get_tree().paused:
		return false
	return Input.is_action_just_pressed("ui_accept")

func _wait_for_advance(target: Node2D) -> void:
	await get_tree().process_frame
	while not _advance_just_pressed():
		if _tick_skip():
			return
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
	load_json("res://chat_line/test/battle_chat_lines.json")

func load_campfire_json() -> void:
	load_json("res://chat_line/test/campfire_chat_lines.json")

func load_opening_json() -> void:
	load_json("res://chat_line/test/opening_chat_lines.json")

func load_death_json() -> void:
	load_json("res://chat_line/test/death_chat_lines.json")

func load_ending_json() -> void:
	load_json("res://chat_line/test/ending_chat_lines.json")

# === construct and play a conversation ===

## 会話を再生できるかどうかだけを先に判定する。
## 「会話を始める前提で扉を閉める／壁を出す」ような処理は、
## 必ずこれで確認してから状態を変えること。
func can_play_conversation(conversation_tag: String) -> bool:
	return conversations.has(conversation_tag) and speakers.size() > 0


## 会話を再生する。実際に再生を始められたら true。
##
## 【戻り値を足した理由】
## 以前は失敗しても静かに return するだけで、finished も飛ばなかった。
## 呼び出し側（ボス部屋）は finished を待って戦闘を始める作りなので、
## 「透明壁だけ出て、会話も戦闘も始まらない＝詰み」が起きていた。
func play_conversation(conversation_tag: String, allow_skip: bool = true) -> bool:
	if not conversations.has(conversation_tag):
		push_error("Conversation tag not found: %s" % conversation_tag)
		return false
	if speakers.keys().size() == 0:
		push_error("No speakers have been registered. Please register speakers before playing a conversation.")
		return false
	# すでに別の会話が流れている場合は、そちらを打ち切ってから始める。
	# 2本同時に流すと、片方が終わった時点でチャット枠が消え、
	# もう片方は見えないまま入力待ちで固まる（＝詰みの原因）。
	if is_displaying:
		push_warning("Dialogue: '%s' の再生中に '%s' が要求されたので前者を打ち切ります" % [current_tag, conversation_tag])
		_abort_requested = true
		await get_tree().process_frame

	skip_enabled = allow_skip
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
		if line_data.has("camera_target"):
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

		lines.append(Line.new(speaker, line_data["speaker"], style, line_data["text"], text_color, text_size, text_speed, camera_target, box_style, box_side, signal_name))

	await say(conversation_tag, lines)
	return true

# === modify data ===
## 話者の登録をやり直す。部屋の切り替え時に呼ばれるので、
## ここで前の部屋の会話も確実に畳んでおく。
func reset_speakers() -> void:
	cancel()
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

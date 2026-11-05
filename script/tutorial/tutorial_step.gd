class_name TutorialStep
extends Node2D
## チュートリアルの 1 区画。
## 「入る → 会話 → 説明の箱 → 課題 → 達成 → 会話 → 柵が開く」という流れはここで共通に持ち、
## 課題の中身（準備・達成条件・進み具合の表示）だけを派生クラスが書く（Template Method）。

@export var entry_area: Area2D
@export var dummy: TrainingDummy
@export var gate: TutorialGate

@export_group("文章")
@export var intro_conversation: String = ""
@export var clear_conversation: String = ""
@export_multiline var instruction: String = ""
@export var guide_action: StringName = &""

var ctx: TutorialContext
var _last_guide: String = ""


func run(context: TutorialContext) -> void:
	ctx = context
	if entry_area:
		await entry_area.entered
	if dummy:
		ctx.player.set_target_enemy(dummy)

	await _play_conversation(intro_conversation)
	if instruction != "":
		await ctx.show_message(instruction)

	_begin()
	while not _is_cleared():
		_update_guide()
		await get_tree().physics_frame
	_end()

	if dummy:
		dummy.set_guide("達成！")
	await _play_conversation(clear_conversation)
	if gate:
		gate.open()


# === 派生クラスが書くところ ===

func _begin() -> void:
	pass


func _is_cleared() -> bool:
	return true


func _progress_text() -> String:
	return ""


func _end() -> void:
	pass


# === 共通の部品 ===

func _update_guide() -> void:
	if dummy == null:
		return
	var text := _progress_text()
	if text == _last_guide:
		return
	_last_guide = text
	dummy.set_guide(text, guide_action)


func _play_conversation(tag: String) -> void:
	if tag == "" or not Dialogue.can_play_conversation(tag):
		return
	await Dialogue.play_conversation(tag)

class_name TutorialContext
extends RefCounted
## チュートリアルの各区画（TutorialStep）が共通で使うものをまとめて渡す入れ物。
## 区画は「ステージの中身」を直接たどらず、ここに入っているものだけを使う。

var player: CharacterBody2D
var paint_layer: Node2D
var message_box: MessageBox


func _init(_player: CharacterBody2D, _paint_layer: Node2D, _message_box: MessageBox) -> void:
	player = _player
	paint_layer = _paint_layer
	message_box = _message_box


## 箱を出し、閉じられるまでプレイヤーを止めておく。
func show_message(text: String) -> void:
	player.add_control_lock("message")
	await message_box.show_message(text)
	# 閉じた決定キー（Space）がそのままローリングとして拾われないよう、2 物理フレーム待ってから動かす
	await message_box.get_tree().physics_frame
	await message_box.get_tree().physics_frame
	player.remove_control_lock("message")


func set_player_mana_ratio(ratio: float) -> void:
	var mana: ManaComponent = player.mana_component
	var target := mana.get_max_mana() * ratio
	if mana.get_mana() > target:
		mana.spend(mana.get_mana() - target, ManaComponent.Reason.SPEND)
	elif mana.get_mana() < target:
		mana.restore(target - mana.get_mana(), ManaComponent.Reason.REGENERATE)

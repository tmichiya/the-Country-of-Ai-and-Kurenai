extends Node
## 周回（ループ）の進行と、ステージ間の遷移をまとめて管理する。
##
## 「会話 → ボス戦 → 焚火 → 次の周回」というゲーム全体の流れは、
## 個々のシーン（ボス戦・焚火）からは見えないようにし、
## 各シーンは「戦いに勝った／負けた」「休憩が終わった」を
## GameManager に伝えるだけでいいようにする。

signal loop_advanced(loop_count: int)

const BOSS_STAGE: PackedScene = preload("res://scene/test_scene.tscn")
const CAMPFIRE_STAGE: PackedScene = preload("res://scene/campfire_stage.tscn")

## 今何周目か（0周目 = 最初の戦い）
var loop_count: int = 0


## シーン切り替えの実処理はここに一本化する。
## 将来「グワンと歪んで切り替わる」演出を挟みたくなったら、
## この関数の中身だけ差し替えれば全呼び出し元は変更不要になる。
func _change_stage(next_stage: PackedScene) -> void:
	get_tree().change_scene_to_packed(next_stage)


## ボス撃破 → 焚火へ
func go_to_campfire() -> void:
	_change_stage(CAMPFIRE_STAGE)


## 焚火を終えて次の周回のボス戦へ（周回数を進める）
func advance_loop_and_fight() -> void:
	loop_count += 1
	loop_advanced.emit(loop_count)
	_change_stage(BOSS_STAGE)


## プレイヤーが敗北した場合のやり直し（周回数は進めない）
func retry_boss() -> void:
	_change_stage(BOSS_STAGE)


## 「決定入力（ui_accept）が押されるまで待つ」共通処理。
## 結果画面やイベントの「次へ」待ちに使う。
func wait_for_confirm() -> void:
	await get_tree().process_frame
	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

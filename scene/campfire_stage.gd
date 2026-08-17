extends Node2D
## 焚火ステージ（現時点では仮実装）。
##
## 今はまだスキル解放システムがないので、
## 「今何周目か表示 → 決定キーで次の戦闘へ」というだけの
## 最小限の中継シーンにしてある。
## 中身はここだけ差し替えれば、外（GameManager・ボス戦側）は
## 一切変更せずにスキル解放UIへ拡張できる。

@onready var loop_label: Label = $UILayer/LoopLabel
@onready var prompt_label: Label = $UILayer/PromptLabel

func _ready() -> void:
	loop_label.text = "第 %d 周" % (GameManager.loop_count + 1)
	prompt_label.visible = false
	_wait_and_advance()

func _wait_and_advance() -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	prompt_label.visible = true
	await GameManager.wait_for_confirm()
	GameManager.advance_loop_and_fight()

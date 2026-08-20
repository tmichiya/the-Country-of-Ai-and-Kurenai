extends Node

signal loop_advanced(loop_count: int)
signal campfire_requested
signal boss_requested
signal next_battle_requested

var loop_count: int = 0

func go_to_campfire() -> void:
	campfire_requested.emit()

func advance_loop_and_fight() -> void:
	# 実際のループ加算は遷移が確定したときに一度だけ行う（main の _transitioning ガード内）。
	# ここで加算しないので、warp が多重発火／リセット時に誤発火しても加算は増えない。
	next_battle_requested.emit()

## 遷移が確定した瞬間に一度だけ呼ぶ。ここでループを進める。
func commit_loop_advance() -> void:
	loop_count += 1
	loop_advanced.emit(loop_count)

func go_to_boss() -> void:
	boss_requested.emit()

func wait_for_confirm() -> void:
	await get_tree().process_frame
	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

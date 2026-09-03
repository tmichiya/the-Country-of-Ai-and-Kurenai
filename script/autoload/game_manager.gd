extends Node

signal loop_advanced(loop_count: int)
signal campfire_requested
signal boss_requested
signal next_battle_requested

const room_scene_paths = {
	"opening": "res://scene/stage/opening_stage.tscn",
	"main": "res://scene/main.tscn",
	"ending": "res://scene/stage/ending_stage.tscn",
}

var loop_count: int = 0

func change_scene_to(scene_name: String) -> void:
	if room_scene_paths.has(scene_name):
		await Effects.fade_in(1.0)
		get_tree().change_scene_to_file(room_scene_paths[scene_name])
		await get_tree().create_timer(0.5, true, false, true).timeout
		await Effects.fade_out(1.0)
	else:
		push_error("Unknown scene name: %s" % scene_name)

func go_to_campfire() -> void:
	campfire_requested.emit()

func go_to_title() -> void:
	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	await Effects.fade_in(4.0)
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().change_scene_to_file(room_scene_paths["opening"])

func go_to_ending() -> void:
	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	await get_tree().create_timer(1.0, true, false, true).timeout
	await Effects.fade_in(3.0)
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().change_scene_to_file(room_scene_paths["ending"])
	await Effects.fade_out(3.0)


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

## ポーズメニューから「タイトルへ」戻るとき用。
## 暗転はポーズ側で済ませてある前提で、シーンを差し替えて明転だけ行う。
func return_to_opening() -> void:
	loop_count = 0
	get_tree().change_scene_to_file(room_scene_paths["opening"])
	# change_scene_to_file はフレーム末に遅延実行される。
	# 新シーン（Title）の _ready がフェード設定を上書きするので、それを待ってから塗り直す。
	await get_tree().process_frame
	await get_tree().process_frame
	Effects.set_fade_color(Vector3(0.05, 0.05, 0.05))
	Effects.set_fade_alpha(1.0)
	await Effects.fade_out(1.0)
	# タイトルの薄白ビネット設定に戻す（title.gd の _ready と同じ値）。
	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	Effects.set_fade_parameter(0.0)
	Effects.set_fade_alpha(0.2)
	Effects.set_visible_fade(true)

func wait_for_confirm() -> void:
	await get_tree().process_frame
	# process_frame は paused=true でも発火するので、ポーズ中は入力を見ないようにする。
	while get_tree().paused or not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

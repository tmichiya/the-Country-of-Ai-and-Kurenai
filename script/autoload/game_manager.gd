extends Node

signal loop_advanced(loop_count: int)
signal campfire_requested
signal boss_requested_on_warp_transition
signal boss_requested_on_normal_transition
## 1周を最初からやり直す合図（タイトルへ戻った / エンディングを見た後）。
## 各ステージはこれを購読して「初回会話フラグ」などを初期状態へ戻す。
signal run_reset
signal data_selected

const room_scene_paths = {
	"opening": "res://scene/stage/opening_stage.tscn",
	"main": "res://scene/main.tscn",
	"ending": "res://scene/stage/ending_stage.tscn",
	"result" : "res://scene/stage/result_score.tscn",
}

enum Stage {
	OPENING,
	CAMPFIRE,
	BOSS,
	ENDING,
	RESULT
}

var loop_count: int = 0

var wave_times : Array[float] = [0.0, 0.0, 0.0]

var easy_mode: bool = false

var is_transitioning: bool = false

var current_stage: Stage = Stage.OPENING

func set_transitioning(value: bool) -> void:
	is_transitioning = value

func set_current_stage(stage: Stage) -> void:
	current_stage = stage

func get_loop_count() -> int:
	return loop_count

func get_current_stage() -> Stage:
	return current_stage

func reset_run_state() -> void:
	Engine.time_scale = 1.0
	Dialogue.cancel()
	run_reset.emit()
	PauseMenu.set_available(false)

func set_easy_mode(value: bool) -> void:
	easy_mode = value

func reset_save_data() -> void:
	var default_game_data = SaveManager.default_game_data
	SaveManager.save_game(default_game_data)

func load_save_data() -> void:
	var game_data = SaveManager.get_save_data()
	var data_game_version = ""
	if game_data != null:
		data_game_version = game_data.game_version
		loop_count = game_data.loop_count
		wave_times = game_data.wave_times
		easy_mode = game_data.easy_mode
		current_stage = game_data.current_stage
		Dialogue.set_readed_conversations(game_data.readed_conversations.duplicate())
	else:
		# セーブデータが存在しない場合は初期値を使用
		_set_default_game_data()
		print("[GameManager]: No save data found. Using default values.")

	# セーブデータのバージョンが古い場合は、警告
	if data_game_version != SaveManager.default_game_data.game_version:
			push_warning("[GameManager]: Save data version mismatch. Expected: %s, Found: %s" %
				[SaveManager.default_game_data.game_version, data_game_version]) 

	data_selected.emit()


	print("[GameManager]: Loaded save data - Loop Count: %d, Wave Times: %s, Easy Mode: %s, Current Stage: %s" %
		[loop_count, wave_times, easy_mode, current_stage])

	# 画面にセーブデータを反映
	if current_stage == Stage.OPENING:
		pass  # タイトル画面のフェードアウトは title.gd 側で行う
	else:
		if current_stage == Stage.CAMPFIRE or current_stage == Stage.BOSS:
			change_scene_to_main()
		elif current_stage == Stage.ENDING:
			go_to_ending()
		elif current_stage == Stage.RESULT:
			go_to_result_score()
		else:
			push_error("[GameManager]: Unknown stage: %s" % current_stage)


func add_wave_time(loop_index: int, seconds: float) -> void:
	if loop_index < 0 or loop_index >= wave_times.size():
		# 周回リセット漏れなどで想定外の値が来ても、配列外アクセスで落とさない。
		push_warning("add_wave_time: 想定外の loop_index=%d" % loop_index)
		return
	wave_times[loop_index] += seconds

func get_total_time() -> float:
	var total := 0.0
	for t in wave_times:
		total += t
	return total

static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := fmod(seconds, 60.0)
	return "%d:%05.2f" % [m, s]

func change_scene_to_main() -> void:
	Effects.set_fade_color(Effects.BLACK_VEC3)
	await Effects.fade_in(1.0)
	get_tree().change_scene_to_file(room_scene_paths["main"])
	loop_advanced.emit(loop_count)
	await get_tree().create_timer(0.5, true, false, true).timeout
	await Effects.fade_out(1.0)

func go_to_result_score() -> void:
	Effects.set_fade_color(Effects.WHITE_VEC3)
	await Effects.fade_in(4.0)
	get_tree().change_scene_to_file(room_scene_paths["result"])
	current_stage = Stage.RESULT
	await Effects.fade_out(2.0)
	
func go_to_campfire() -> void:
	print("[GameManager]: Transitioning to campfire scene.")
	current_stage = Stage.CAMPFIRE
	campfire_requested.emit()
	Effects.set_fade_color(Effects.BLACK_VEC3)

func go_to_title() -> void:
	Effects.set_fade_color(Effects.WHITE_VEC3)
	await Effects.fade_in(4.0)
	await get_tree().create_timer(1.0, true, false, true).timeout
	reset_run_state()
	get_tree().change_scene_to_file(room_scene_paths["opening"])
	await Effects.fade_out(2.0)

func go_to_ending() -> void:
	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	await get_tree().create_timer(1.0, true, false, true).timeout
	await Effects.fade_in(3.0)
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().change_scene_to_file(room_scene_paths["ending"])
	current_stage = Stage.ENDING
	await Effects.fade_out(3.0)

func go_to_boss_on_warp() -> void:
	current_stage = Stage.BOSS
	boss_requested_on_warp_transition.emit()

func go_to_boss_on_normal_transition() -> void:
	current_stage = Stage.BOSS
	boss_requested_on_normal_transition.emit()

## ポーズメニューから「タイトルへ」戻るとき用。
## 暗転はポーズ側で済ませてある前提で、シーンを差し替えて明転だけ行う。
func return_to_opening() -> void:
	reset_run_state()
	get_tree().change_scene_to_file(room_scene_paths["opening"])
	await get_tree().process_frame
	await get_tree().process_frame
	Effects.set_fade_color(Effects.BLACK_VEC3)
	Effects.set_fade_alpha(1.0)
	await Effects.fade_out(1.0)

func commit_loop_advance() -> void:
	loop_count += 1
	loop_advanced.emit(loop_count)

func wait_for_confirm() -> void:
	await get_tree().process_frame
	while get_tree().paused or not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

func request_quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

## 外部オブジェクトから呼ばれることを想定
func save_game() -> void:
	var game_data = SaveManager.GameData.new(
		ProjectSettings.get_setting("application/config/version"),
		loop_count,
		wave_times,
		easy_mode,
		current_stage,
		Dialogue.readed_conversations.duplicate()
	)
	SaveManager.save_game(game_data)

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)  # WM_QUIT_REQUEST を自前で処理する

func _notification(what) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _set_default_game_data() -> void:
	loop_count = SaveManager.default_game_data.loop_count
	wave_times = SaveManager.default_game_data.wave_times.duplicate()
	easy_mode = SaveManager.default_game_data.easy_mode
	current_stage = SaveManager.default_game_data.current_stage
	Dialogue.set_readed_conversations(SaveManager.default_game_data.readed_conversations.duplicate())

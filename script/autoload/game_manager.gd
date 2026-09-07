extends Node

signal loop_advanced(loop_count: int)
signal campfire_requested
signal boss_requested
signal next_battle_requested
## 1周を最初からやり直す合図（タイトルへ戻った / エンディングを見た後）。
## 各ステージはこれを購読して「初回会話フラグ」などを初期状態へ戻す。
signal run_reset

const room_scene_paths = {
	"opening": "res://scene/stage/opening_stage.tscn",
	"main": "res://scene/main.tscn",
	"ending": "res://scene/stage/ending_stage.tscn",
	"result" : "res://scene/stage/result_score.tscn",
}

var loop_count: int = 0

var wave_times : Array[float] = [0.0, 0.0, 0.0]

## 部屋の切り替え演出中か（main.gd が set_transitioning() で更新する）。
## ワープ地点のように「踏んだら遷移が始まる」場所は、これを見て
## 遷移中なら何もしないようにする。遷移が始まらないのに
## プレイヤーの操作だけロックしてしまう、という取り残しを防ぐ。
var is_transitioning: bool = false

func set_transitioning(value: bool) -> void:
	is_transitioning = value

func get_loop_count() -> int:
	return loop_count

## 1周ぶんの進行状態を初期化する。
## タイトルへ戻る経路が複数あるので、リセット漏れが起きないよう入口を1つにまとめる。
## 「どこか1か所でも reset を書き忘れると次のプレイが壊れる」形を避けるのが狙い。
func reset_run_state() -> void:
	loop_count = 0
	wave_times = [0.0, 0.0, 0.0]
	Engine.time_scale = 1.0          # スロー演出の途中で抜けた場合の保険
	Dialogue.cancel()                # 走りっぱなしの会話を残さない
	run_reset.emit()

## その周回の戦闘タイムを「加算」する。
##
## 加算にしてあるのは、敗北して焚火からやり直した場合もそのぶん積むため。
## ＝リトライしてもタイムは戻らない。
## 時の神は時を戻せても、プレイヤーの記録は戻さない、という筋にもなっている。
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

## 表示と送信で桁がバラつかないよう、整形は1か所に集約する。
## 例: 83.4 → "1:23.40"
static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := fmod(seconds, 60.0)
	return "%d:%05.2f" % [m, s]

func change_scene_to(scene_name: String) -> void:
	if room_scene_paths.has(scene_name):
		await Effects.fade_in(1.0)
		get_tree().change_scene_to_file(room_scene_paths[scene_name])
		await get_tree().create_timer(0.5, true, false, true).timeout
		await Effects.fade_out(1.0)
	else:
		push_error("Unknown scene name: %s" % scene_name)

func go_to_result_score() -> void:
	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	await Effects.fade_in(4.0)
	get_tree().change_scene_to_file(room_scene_paths["result"])
	await Effects.fade_out(2.0)

func go_to_campfire() -> void:
	campfire_requested.emit()

func go_to_title() -> void:
	Effects.set_fade_color(Vector3(1.0, 1.0, 1.0))
	await Effects.fade_in(4.0)
	await get_tree().create_timer(2.0, true, false, true).timeout
	# 【重要】ここで周回状態を戻す。
	# 以前はこのリセットが無かったため、エンディング後にタイトルへ戻ると
	# loop_count が 3 のまま次のプレイに持ち越されていた。
	# 薄暮の使用可能技は loop_count で引くので 3 では空配列になり、
	# choose_attack() が常に "" を返して薄暮が一切攻撃しなくなる
	# ＝勝てない＝先へ進めない、という詰みになっていた。
	reset_run_state()
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
	reset_run_state()
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

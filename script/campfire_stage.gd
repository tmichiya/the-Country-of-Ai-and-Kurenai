extends Node2D
## 焚火ステージ（歩けるルーム版）。
## ・焚火に近づく → 決定キーでスキル画面（仮）の開閉
## ・奥の地点（WarpArea）に到達 → 次のボス戦へ（GameManager 経由）

@export var player: CharacterBody2D
@export var player_spawn: Marker2D
@export var chat_marker: Marker2D
@export var warp_area: Node2D
@export var statue: Node2D

@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera

@onready var center_container: CenterContainer = $CenterContainer

@onready var chat_start_area: Area2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/ChatStartArea
@onready var statue_chat_area: Area2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/StatueChatArea

@onready var lighting_night: CanvasModulate = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Night
@onready var lighting_morning: CanvasModulate = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Morning
@onready var lighting_dawn: CanvasModulate = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Dawn
@onready var lighting_predawn: CanvasModulate = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Predawn
@onready var lighting_evening: CanvasModulate = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Evening

@onready var statue_triangle: Node2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Statue/Triangle

var player_in_bonfire_range := false
var loop_count: int = 0

var is_first_intro_chat: bool = true

## この部屋が今アクティブか（Area や Dialogue のシグナルは
## process_mode を DISABLED にしても止まらないので自前で持つ）
var is_active: bool = false

func _ready() -> void:
	GameManager.loop_advanced.connect(_on_loop_advanced)
	GameManager.run_reset.connect(_on_run_reset)
	warp_area.entered.connect(_on_warp_entered)
	chat_start_area.entered.connect(_on_chat_start_entered)
	statue_chat_area.entered.connect(_on_statue_chat_entered)
	_activate_lighting()

	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

var bird_se_timer := 0.0
var bird_se_interval := 1.0
func _process(delta: float) -> void:
	if loop_count == 1:
		bird_se_timer += delta
		if bird_se_timer >= bird_se_interval:
			bird_se_timer = 0.0
			bird_se_interval = randf_range(6.0, 10.0)
			AudioManager.play_random_bird_se()

	player.mana_component.restore(100 * delta)

func _activate_lighting() -> void:
	if loop_count == 0:
		lighting_night.visible = true
		lighting_morning.visible = false
		lighting_dawn.visible = false
		lighting_predawn.visible = false
		lighting_evening.visible = false
	elif loop_count == 1:
		lighting_night.visible = false
		lighting_morning.visible = false
		lighting_dawn.visible = false
		lighting_predawn.visible = false
		lighting_evening.visible = true
	elif loop_count == 2:
		lighting_night.visible = false
		lighting_morning.visible = false
		lighting_dawn.visible = false
		lighting_predawn.visible = true
		lighting_evening.visible = false

func _get_conversation_tag() -> String:
	return "loop%d" % loop_count

func _on_chat_start_entered() -> void:
	if not is_active:
		return
	player.set_process_to(false)
	player.stop_movement("fade_in")
	await Effects.fade_in(1.0)
	player.global_position = chat_marker.global_position
	Camera.activate_brief_camera()
	await Effects.fade_out(1.0)
	if is_first_intro_chat:
		is_first_intro_chat = false
		await Dialogue.play_conversation(_get_conversation_tag() + "_campfire_intro")
	player.set_process_to(true)


func _on_statue_chat_entered() -> void:
	if not is_active:
		return
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.add_target("statue", statue)
	await Dialogue.play_conversation(_get_conversation_tag() + "_statue_help")
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	statue_triangle.visible = false


func _on_loop_advanced(loop_c: int) -> void:
	is_first_intro_chat = true
	loop_count = loop_c

func _on_run_reset() -> void:
	loop_count = 0
	is_first_intro_chat = true

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

func set_active(active: bool) -> void:
	is_active = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	ui_layer.visible = active
	camera.enabled = active
	if not active:
		# 部屋を出るときに、この部屋が始めた会話を持ち越さない
		Dialogue.cancel()

func reset_room() -> void:
	player.reset()                          # ここで操作ロックは全部クリアされる
	player.remove_control_lock("warp")      # 念のため（reset より後に付いた場合の保険）
	warp_area.set_monitoring_active(true)   # ワープ地点を再アーム（重なりが解けてから有効化される）
	Camera.set_node_data($CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera, $CenterContainer/EffectLayer/SubViewportContainer, $CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("player")
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(1200, 1450))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("statue", statue)
	Dialogue.load_campfire_json()
	Effects.set_can_shake_decay(true)
	Effects.shake(0.0)
	statue_chat_area.set_monitoring_active(true)
	_activate_lighting()
	player.remove_control_lock("warp")
	statue_triangle.visible = true

	if loop_count <= 0:
		if is_first_intro_chat:
			chat_start_area.set_monitoring_active(true)
		player.global_position = player_spawn.global_position
	else:
		chat_start_area.set_monitoring_active(false)
		player.global_position = chat_marker.global_position
		Camera.activate_brief_camera()
		if is_first_intro_chat:
			is_first_intro_chat = false
			Dialogue.play_conversation(_get_conversation_tag() + "_campfire_intro")
	
	# loop_count が想定外の値でも配列外アクセスで落ちないようにする
	var names := ["深夜", "夕方", "未明"]
	ui_layer.set_title_screen_time(names[clampi(loop_count, 0, names.size() - 1)])
	ui_layer.show_title_screen()

	if loop_count == 0 or loop_count == 2:
		AudioManager.play_bgm(AudioManager.BGM_CAMPFIRE_NIGHT, 0.5, true)
	else:
		AudioManager.play_bgm(AudioManager.BGM_EVENING_NIGHT, 0.5, true)

func _on_warp_entered() -> void:
	if not is_active:
		return
	# すでに遷移演出が走っているなら何もしない。
	# ここで操作だけロックしても、main 側は多重遷移を弾くので
	# ロックを外す機会が来ずプレイヤーが動けなくなる。
	if GameManager.is_transitioning:
		return
	# 【重要】ワープを踏んだ瞬間に操作を奪う。
	#
	# 以前はここで止めていなかったので、暗転している 1 秒のあいだも
	# プレイヤーは自由に動けた。ローリングは通常の 4 倍速で移動するため、
	# 連打していると暗転中に焚火側の別の判定エリア（石像や導入会話）へ届いてしまい、
	# 「ボス部屋がロードされたときに焚火の会話がまだ開いたまま」という
	# 二重会話状態を作れてしまう。これが透明壁だけ残って詰む事故の温床だった。
	player.add_control_lock("warp")
	player.stop_movement("warp")
	GameManager.advance_loop_and_fight()

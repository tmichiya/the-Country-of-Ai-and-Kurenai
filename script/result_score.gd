extends Node2D

@onready var center_container: CenterContainer = $CanvasLayer/CenterContainer
@onready var wave_1_score: PanelContainer = $CanvasLayer/CenterContainer/Result/Wave1Score
@onready var wave_2_score: PanelContainer = $CanvasLayer/CenterContainer/Result/Wave2Score
@onready var wave_3_score: PanelContainer = $CanvasLayer/CenterContainer/Result/Wave3Score
@onready var total_score: PanelContainer = $CanvasLayer/CenterContainer/Result/TotalScore

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

	# str() のままだと "83.4000015258789" のような生の float が出る。
	# 整形は GameManager.format_time に集約してあるので、表示側はそれを呼ぶだけ。
	wave_1_score.set_text(GameManager.format_time(GameManager.wave_times[0]))
	wave_2_score.set_text(GameManager.format_time(GameManager.wave_times[1]))
	wave_3_score.set_text(GameManager.format_time(GameManager.wave_times[2]))
	total_score.set_text(GameManager.format_time(GameManager.get_total_time()))

	# 【送信はここに置かない】
	# この画面は「タイムを表示する」だけの責務にしておく。
	# unityroom への送信はクリア判定そのものなので、
	# 必ず通る ending_stage._ready() に置いてある（この画面はまだ未配線でも動く）。
	animation_player.play("result/show_result")


	animation_player.animation_finished.connect(_on_result_animation_finished)


func _on_result_animation_finished(anim_name: String) -> void:
	if anim_name == "result/show_result":
		GameManager.go_to_title()


func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

func play_next_chat_se() -> void:
	AudioManager.play_se("next_chat")

func play_bell_1_se() -> void:
	AudioManager.play_se("bell_1")

func play_bell_2_se() -> void:
	AudioManager.play_se("bell_2")

extends Node2D
## 訓練場（チュートリアル）。下から順に TutorialStep を 1 つずつ実行し、最後に謁見へ向かう。
## 区画の中身は各 TutorialStep が持つので、このスクリプトは「順番に流す」ことと部屋の準備だけを行う。

@export var player: CharacterBody2D
@export var paint_layer: Node2D
@export var message_box: MessageBox
@export var steps: Array[TutorialStep] = []
@export var exit_area: Area2D
## 訓練なので倒れない。魔力がこの割合を下回ったら rescue_mana_ratio まで戻す。
@export_range(0.0, 1.0) var safety_mana_ratio: float = 0.1
@export_range(0.0, 1.0) var rescue_mana_ratio: float = 0.3
@export var map_size: Vector2 = Vector2(320, 1440)

@onready var center_container: CenterContainer = $CenterContainer
@onready var camera: Camera2D = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/Camera
@onready var viewport_container: SubViewportContainer = $CenterContainer/EffectLayer/SubViewportContainer
@onready var sub_viewport: SubViewport = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport

var _rescue_pending: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()
	player.mana_changed.connect(_on_player_mana_changed)
	_setup_room()
	_run()


func _setup_room() -> void:
	player.reset()
	player.set_auto_regeneration_mode(false)

	Camera.set_node_data(camera, viewport_container, sub_viewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.set_current_target("player")
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_zoom_value(Vector2(1.75, 1.75), 0.1)
	Camera.map_rect = Rect2(Vector2.ZERO, map_size)
	# 上へ進むステージなので、少し先（上）が見えるようにずらす
	Camera.set_offset(Vector2(0, -30), 0.0)
	Camera.set_do_brief_camera(true)

	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.load_tutorial_json()

	AudioManager.play_bgm(AudioManager.BGM_TITLE, 0.5)


func _run() -> void:
	player.add_control_lock("intro")
	await get_tree().create_timer(1.0, true, false, true).timeout
	PauseMenu.set_available(true)
	player.remove_control_lock("intro")
	await Dialogue.play_conversation("tutorial_intro")

	var ctx := TutorialContext.new(player, paint_layer, message_box)
	for step in steps:
		await step.run(ctx)

	await exit_area.entered
	await Dialogue.play_conversation("tutorial_end")
	player.add_control_lock("exit")
	PauseMenu.set_available(false)
	GameManager.finish_tutorial()


func _on_player_mana_changed(current: float, max_mana: float, _reason: ManaComponent.Reason) -> void:
	if _rescue_pending or current >= max_mana * safety_mana_ratio:
		return
	_rescue_pending = true
	_rescue_mana.call_deferred()


func _rescue_mana() -> void:
	await get_tree().create_timer(0.6).timeout
	var mana: ManaComponent = player.mana_component
	var target := mana.get_max_mana() * rescue_mana_ratio
	if mana.get_mana() < target:
		mana.restore(target - mana.get_mana(), ManaComponent.Reason.REGENERATE)
	_rescue_pending = false


func _fit_center_container() -> void:
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

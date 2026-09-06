extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@onready var battle_manager: Node2D = $Battle
@onready var center_container: CenterContainer = $Battle/CenterContainer
@onready var campfire_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/CampfireArea
@onready var player: CharacterBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Player
@onready var hakubo: CharacterBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Hakubo
@onready var ui_manager: CanvasLayer = $Battle/UILayer
@onready var event_collision: StaticBody2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/StageBackground/EventCollision

@onready var chat_start_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/ChatStartArea
@onready var chat_1_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Chat1Area
@onready var zoom_out_area: Area2D = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/ZoomOutArea

@onready var lighting_night: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Night
@onready var lighting_morning: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Morning
@onready var lighting_dawn: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Dawn
@onready var lighting_predawn: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Predawn
@onready var lighting_evening: CanvasModulate = $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/TimeLighting/Evening

@onready var hud: Control = $Battle/UILayer/CenterContainer/HUD

enum StageState {
	WALK_IN,
	PRE_TALK,
	BATTLE,
	POST_TALK,
	WALK_OUT,
	PLAYER_DEAD
}

var state: StageState
var loop_count: int = 0

var is_first_intro_chat: bool = true
var is_first_pre_chat: bool = true
var is_first_post_chat: bool = true

## この部屋が今アクティブか。Dialogue や Area のシグナルは
## process_mode を DISABLED にしても止まらないので、
## 「今この部屋にいるのか」を自前で持って弾く必要がある。
var is_active: bool = false

## この部屋が自分で再生を始めた会話タグ。
## Dialogue.finished は全部屋に broadcast されるので、
## 「タグの末尾が pre か」ではなく「自分が始めたそのタグか」で判定する。
## 焚火や前の周回の会話が遅れて終わったときに戦闘が暴発するのを防ぐ。
var _my_pre_tag: String = ""
var _my_post_tag: String = ""

## reset_room のたびに増える世代番号。
## _start_camera_motion() は await を挟むコルーチンなので、
## 部屋に入り直すと前回のぶんが宙に浮いたまま走り続けてしまう。
## 世代が変わったら古いコルーチンは黙って降りる。
var _room_generation: int = 0

func reset_room() -> void:
	_room_generation += 1
	state = StageState.WALK_IN
	_my_pre_tag = ""
	_my_post_tag = ""
	player.set_process_to(true)
	battle_manager.reset_battle()
	Camera.set_node_data($Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Camera, $Battle/CenterContainer/EffectLayer/SubViewportContainer, $Battle/CenterContainer/EffectLayer/SubViewportContainer/SubViewport)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)
	Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
	Camera.set_current_target("player")
	Camera.set_offset(Vector2(0, 0), 0)
	Camera.set_zoom_value(Vector2(1.5, 1.5), 0.1)
	Camera.map_rect = Rect2(Vector2.ZERO, Vector2(1200, 1750))
	Dialogue.reset_speakers()
	Dialogue.add_speaker("player", player)
	Dialogue.add_speaker("hakubo", hakubo)
	Dialogue.load_battle_json()
	chat_start_area.set_monitoring_active(true)
	chat_1_area.set_monitoring_active(true)
	zoom_out_area.set_monitoring_active(true)
	campfire_area.set_monitoring_active(true)
	_activate_lighting()
	set_hud_visible(false)
	_set_event_wall(false)

	_start_camera_motion(_room_generation)

	AudioManager.play_bgm(AudioManager.BGM_BATTLE_STAGE, 0.5, true)

func reset_player_death_effects() -> void:
	battle_manager.reset_player_death_effects()

## 戦闘場を囲う透明壁の ON/OFF。
## 「壁を立てたのに戦闘も会話も始まらない」と詰むので、
## 出し入れは必ずこの関数を通して、どこで立てたかを追えるようにする。
func _set_event_wall(active: bool) -> void:
	event_collision.collision_layer = 1 if active else 0

func _activate_lighting() -> void:
	if loop_count == 0:
		lighting_night.visible = false
		lighting_morning.visible = true
		lighting_dawn.visible = false
		lighting_predawn.visible = false
		lighting_evening.visible = false
	elif loop_count == 1:
		lighting_night.visible = true
		lighting_morning.visible = false
		lighting_dawn.visible = false
		lighting_predawn.visible = false
		lighting_evening.visible = false
	elif loop_count == 2:
		lighting_night.visible = false
		lighting_morning.visible = false
		lighting_dawn.visible = true
		lighting_predawn.visible = false
		lighting_evening.visible = false

func _start_camera_motion(generation: int) -> void:
	if not Camera.targets.has("hakubo"):
		Camera.add_target("hakubo", hakubo)
	# 入場演出中は "intro" という理由でロックする。
	# 会話の終了で勝手に解除されないよう、Dialogue とは別の鍵にしてある。
	player.add_control_lock("intro")
	Camera.set_current_target("hakubo")
	await get_tree().create_timer(3.0, true, false, true).timeout
	if generation != _room_generation:
		return   # 途中で部屋に入り直された。古い演出はここで降りる

	_show_title_screen()

	Camera.set_follow_speed(2.0)
	Camera.set_current_target("player")
	player.remove_control_lock("intro")
	await get_tree().create_timer(2.0, true, false, true).timeout
	if generation != _room_generation:
		return
	Camera.set_follow_speed(8.0)
	Camera.reset_target_dictionary()
	Camera.add_target("player", player)

func _show_title_screen() -> void:
	# loop_count が想定外（周回リセット漏れなど）でも
	# ここで配列外アクセスして演出コルーチンごと落ちないようにする。
	var names := ["早朝", "深夜", "夜明け前"]
	ui_manager.set_title_screen_time(names[clampi(loop_count, 0, names.size() - 1)])
	ui_manager.show_title_screen()

func _get_conversation_tag() -> String:
	return "loop%d" % loop_count

# 実際に戦闘を始めるスイッチ。会話の有無に関係なくここを通す。
func _begin_battle() -> void:
	# 【暴発防止】
	# この部屋にいないとき、あるいは前会話フェーズ以外から呼ばれたら何もしない。
	# 以前は Dialogue.finished を「タグの末尾が pre か」だけで拾っていたため、
	# 焚火にいる間に前の周回の会話が終わっただけで戦闘が始まり、
	# 戻ってきた瞬間からボスが動いている、という事故が起きえた。
	if not is_active:
		push_warning("boss_stage: 部屋が非アクティブなので戦闘開始を無視しました")
		return
	if state != StageState.PRE_TALK and state != StageState.WALK_IN:
		push_warning("boss_stage: state=%d からの戦闘開始を無視しました" % state)
		return
	state = StageState.BATTLE
	set_hud_visible(true)
	battle_started.emit()
	player.mana_component.restore(100.0)

	if loop_count == 0:
		AudioManager.play_bgm(AudioManager.BGM_BATTLE_LOOP0, 0.5, true)
	elif loop_count == 1:
		AudioManager.play_bgm(AudioManager.BGM_BATTLE_LOOP1, 0.5, true)
	elif loop_count == 2:
		AudioManager.play_bgm(AudioManager.BGM_BATTLE_LOOP2, 0.5, true)

func _on_chat_start_area_entered() -> void:
	# 入場中(WALK_IN)以外で踏んでも無視する。
	# 戦闘中や退場中に踏み直して透明壁が立ち直る事故を防ぐ。
	if not is_active or state != StageState.WALK_IN:
		return

	state = StageState.PRE_TALK
	if not Camera.targets.has("hakubo"):
		Camera.add_target("hakubo", hakubo)

	var tag := _get_conversation_tag() + "_pre"
	# 【重要】壁を立てる前に「本当に会話を始められるか」を確かめる。
	#
	# 以前は先に壁を立ててから play_conversation() を呼んでいた。
	# 会話タグが無い・話者が未登録などで再生に失敗すると finished が飛ばず、
	# _begin_battle() も呼ばれないまま透明壁だけが残って詰んでいた。
	# 「会話が確実に始まるときだけ壁を立てる」に変えれば、その詰み方が消える。
	if is_first_pre_chat and Dialogue.can_play_conversation(tag):
		is_first_pre_chat = false
		_my_pre_tag = tag
		_set_event_wall(true)
		Dialogue.play_conversation(tag)
		# 会話が終わると _on_dialogue_finished(tag) 経由で _begin_battle() が呼ばれる
	else:
		# 会話は既に見た／会話データが無い。どちらの場合も直接戦闘を開始する。
		_set_event_wall(true)
		_begin_battle()
	campfire_area.set_monitoring_active(true)

func _on_chat_1_area_entered() -> void:
	if not is_active:
		return
	if is_first_intro_chat:
		is_first_intro_chat = false
		Dialogue.play_conversation(_get_conversation_tag() + "_intro")

func _on_campfire_area_entered() -> void:
	if not is_active:
		return
	GameManager.go_to_campfire()

func _on_zoom_out_area_entered() -> void:
	if not is_active:
		return
	Camera.set_zoom_value(Vector2(1, 1), 1.2)

func _on_battle_finished(is_win: bool) -> void:
	if is_win:
		set_hud_visible(false)
		battle_finished.emit(true)
		state = StageState.POST_TALK
		event_collision.collision_layer = 0
		# タグは「今の周回」で引くので、ループを進める前に決めておく。
		var post_tag := _get_conversation_tag() + "_post"
		# 先にループを進める。_advance_after_post() の「最終周回か」判定が
		# 進んだあとの loop_count を見るようにするため。
		GameManager.commit_loop_advance()   # 遷移が確定したここで一度だけループを進める
		if is_first_post_chat and Dialogue.can_play_conversation(post_tag):
			is_first_post_chat = false
			_my_post_tag = post_tag
			Dialogue.play_conversation(post_tag)
		else:
			# 会話が無い（データ欠けなど）なら、会話終了を待たずに自分で次へ進める。
			# 待ってしまうと POST_TALK のまま何も起きず詰む。
			is_first_post_chat = false
			_advance_after_post()
	else:
		GameManager.go_to_campfire()

## Dialogue.finished は全ステージへ一斉に飛ぶ。
## 「末尾が pre / post か」で判定していたので、他の部屋や
## 前の周回の会話が遅れて終わっただけでも反応してしまっていた。
## 自分が始めたタグと完全一致したときだけ動く。
func _on_dialogue_finished(conversation_tag: String) -> void:
	if not is_active:
		return
	if conversation_tag != "" and conversation_tag == _my_pre_tag:
		_my_pre_tag = ""
		_begin_battle()
	elif conversation_tag != "" and conversation_tag == _my_post_tag:
		_my_post_tag = ""
		_advance_after_post()

## 会話の有無に関係なく通る「戦闘後 → 次の場所へ」の一本道。
func _advance_after_post() -> void:
	state = StageState.WALK_OUT
	player.set_process_to(false)
	_set_event_wall(false)

	# 最終ループなら、戦闘後の会話が終わったらエンディングに遷移する。
	if loop_count >= 3:
		GameManager.go_to_ending()
	else:
		GameManager.go_to_campfire()

func _on_loop_advanced(loop_c: int) -> void:
	loop_count = loop_c
	is_first_intro_chat = true
	is_first_pre_chat = true
	is_first_post_chat = true

## 周回そのものが最初からやり直しになったとき（タイトルへ戻ったなど）。
func _on_run_reset() -> void:
	loop_count = 0
	is_first_intro_chat = true
	is_first_pre_chat = true
	is_first_post_chat = true
	_my_pre_tag = ""
	_my_post_tag = ""
	state = StageState.WALK_IN

func set_active(active: bool) -> void:
	# UIを含めた表示非表示
	is_active = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	ui_manager.visible = active
	if not active:
		# 部屋を出るときに自分が始めた会話を残さない。
		# 残すと、焚火にいる間に遅れて終わって戦闘が暴発する。
		if _my_pre_tag != "" or _my_post_tag != "":
			Dialogue.cancel()
		_my_pre_tag = ""
		_my_post_tag = ""

func set_hud_visible(visible: bool) -> void:
	hud.visible = visible

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if battle_manager:
		battle_manager.battle_finished.connect(_on_battle_finished)
	campfire_area.entered.connect(_on_campfire_area_entered)

	chat_start_area.entered.connect(_on_chat_start_area_entered)
	chat_1_area.entered.connect(_on_chat_1_area_entered)
	zoom_out_area.entered.connect(_on_zoom_out_area_entered)
	Dialogue.finished.connect(_on_dialogue_finished)

	GameManager.loop_advanced.connect(_on_loop_advanced)
	GameManager.run_reset.connect(_on_run_reset)

	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()

var mystery_se_timer := 0.0
var mystery_se_interval := 1.0
func _process(delta: float) -> void:
	mystery_se_timer += delta
	if mystery_se_timer >= mystery_se_interval:
		mystery_se_timer = 0.0
		if state != StageState.POST_TALK: 
			mystery_se_interval = randf_range(1.0, 4.0)
		else:
			mystery_se_interval = randf_range(0.2, 0.8)
		AudioManager.play_se("mystery_se")

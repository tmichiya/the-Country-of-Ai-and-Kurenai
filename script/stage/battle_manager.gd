extends Node2D

signal battle_started
signal battle_finished(is_win: bool)

@export var boss_stage: Node2D

@export var player: CharacterBody2D
@export var hakubo: CharacterBody2D
@export var paint_layer: Node2D

@export var dark_stage: Sprite2D
@export var stage_foreground: Sprite2D
@export var one_dot_particles: GPUParticles2D
@export var three_dot_particles: GPUParticles2D
@export var absorbing_one_dot_particles: GPUParticles2D
@export var absorbing_three_dot_particles: GPUParticles2D
## 薄暮を撃破したときの演出
@export var defeat_sequence: HakuboDefeatSequence

@onready var ui_manager: CanvasLayer = $UILayer

var battle_active: bool = true
var player_start_position: Vector2
var hakubo_start_position: Vector2

var is_first_death: bool = true

var battle_timer := BattleTimer.new()

var _timing_wave_index: int = 0

## 戦闘のやり直し・周回リセットのたびに増える世代番号。
## 死亡演出は await を挟むので、途中でタイトルへ戻られたら古い演出はここで降りる。
var _battle_generation: int = 0


func reset_battle() -> void:
	_battle_generation += 1
	battle_active = false
	# 前回の走りかけを持ち越さない。部屋は作り直されないので明示的に戻す。
	defeat_sequence.reset()
	battle_timer.reset()
	player.global_position = player_start_position
	hakubo.global_position = hakubo_start_position
	player.reset()
	hakubo.reset()
	paint_layer.reset()
	setup_ui()

	_dialogue_init()

func _on_run_reset() -> void:
	_battle_generation += 1
	is_first_death = true
	defeat_sequence.reset()

func reset_player_death_effects() -> void:
	dark_stage.visible = false
	stage_foreground.visible = true
	one_dot_particles.emitting = true
	three_dot_particles.emitting = true
	absorbing_one_dot_particles.visible = false
	absorbing_three_dot_particles.visible = false
	absorbing_one_dot_particles.emitting = false
	absorbing_three_dot_particles.emitting = false
	Effects.set_can_shake_decay(true)
	Effects.shake(0)
	player.reset_body_pose()

func _on_player_died() -> void:
	_end_battle(false)

func _on_hakubo_died() -> void:
	_end_battle(true)

func _on_hakubo_mana_broken(killing_count: int) -> void:
	print("hakubo mana broken: %d" % killing_count)
	ui_manager.set_hakubo_break_bars(killing_count)
	ui_manager.burst_hakubo_break_bar(killing_count)

## 撃破演出に渡す材料をまとめる。形態は戦闘開始時に確定した周回番号を使う。
func _make_defeat_context() -> HakuboDefeatSequence.Context:
	var ctx := HakuboDefeatSequence.Context.new()
	ctx.hakubo = hakubo
	ctx.player = player
	ctx.paint_layer = paint_layer
	ctx.ui_manager = ui_manager
	ctx.lighting = boss_stage.get_active_lighting()
	ctx.form = _timing_wave_index
	return ctx

func _end_battle(is_win: bool) -> void:
	if not battle_active:
		return
	battle_active = false
	var generation := _battle_generation

	GameManager.add_wave_time(_timing_wave_index, battle_timer.stop())

	player.set_process_input(false)
	# 撃破時は吹き飛びを見せるため物理処理を残す（hakubo 側で撃破後は移動以外しない）
	if not is_win:
		hakubo.set_process_to(false)
	hakubo.state = hakubo.State.IDLE
	paint_layer.clear_jobs()

	# 死亡演出
	if not is_win:
		AudioManager.stop_bgm()
		AudioManager.play_se("player_dead_se")

		# 周囲が暗くなる
		dark_stage.display()
		stage_foreground.visible = false

		boss_stage.set_hud_visible(false)

		# 吹っ飛ばされる演出
		Camera.reset_target_dictionary()
		Camera.add_target("player", player)
		Camera.set_state(Camera.CameraState.FOLLOW_TARGET)
		var hakubo_vec = Vector2.from_angle(hakubo.direction)

		player.play_death_animation(hakubo_vec.x)
		player.blowed_off(hakubo_vec)

		Effects.shake(5.0)
		await Effects.slowmotion(0.5, 2.0)
		if generation != _battle_generation:
			return
		player.set_process_to(false)

		AudioManager.play_bgm(AudioManager.BGM_PLAYER_DEAD, 0.5, true)
		AudioManager.play_se("earthquake")
		
		one_dot_particles.emitting = false
		three_dot_particles.emitting = false
		absorbing_one_dot_particles.visible = true
		absorbing_three_dot_particles.visible = true
		absorbing_one_dot_particles.emitting = true
		absorbing_three_dot_particles.emitting = true
		var tw = create_tween()
		tw.tween_property(absorbing_one_dot_particles, "amount", 1200, 1.0)
		tw.tween_property(absorbing_three_dot_particles, "amount", 1200, 1.0)
		Effects.set_can_shake_decay(false)
		Effects.smooth_shake(0.0, 1.0, 5.0)

		await get_tree().create_timer(1.0, true, false, true).timeout
		if generation != _battle_generation:
			return

		Dialogue.load_death_json()
		if is_first_death:
			is_first_death = false
			await Dialogue.play_conversation("first_death")
		else:
			await Dialogue.play_conversation("random_%d_death" % (randi() % 6 + 1))
		# 会話が force_close() で打ち切られた（タイトルへ戻った）なら、ワープを要求しない
		if generation != _battle_generation:
			return
		AudioManager.play_bgm(AudioManager.BGM_BATTLE_STAGE, 0.5, true)
	else:
		# 撃破演出。BGM の再開も演出の最後で行う
		player.set_process_to(false)
		boss_stage.set_ambient_muted(true)
		var completed: bool = await defeat_sequence.play(_make_defeat_context())
		boss_stage.set_ambient_muted(false)
		if not completed or generation != _battle_generation:
			return

	player.set_process_to(false)
	battle_finished.emit(is_win)

func _start_battle() -> void:
	battle_active = true
	battle_started.emit()

	# ここにこのコードあんまりよくなさそう
	player.set_target_enemy(hakubo)

	# 計測開始。どの周回のタイムかもここで確定させる。
	_timing_wave_index = GameManager.loop_count
	battle_timer.start()

	Camera.set_state(Camera.CameraState.BATTLE)

## 決着せずに戦闘から離れたときに呼ぶ。
func abandon_battle() -> void:
	if not battle_timer.is_running():
		return   # 決着済み（stop 済み）や、そもそも戦闘前ならここで降りる
	GameManager.add_wave_time(_timing_wave_index, battle_timer.stop())
	battle_active = false

## HUD のタイム表示。ラベルが置かれていなければ ui_manager 側で握り潰される。
func _on_battle_timer_ticked(elapsed: float) -> void:
	var i := clampi(_timing_wave_index, 0, GameManager.wave_times.size() - 1)
	var wave_total: float = GameManager.wave_times[i] + elapsed
	ui_manager.set_time_text(GameManager.format_time(wave_total))

func _on_player_damaged() -> void:
	player.blowed_off((player.global_position - hakubo.global_position).normalized(), 2.0)

func _on_hakubo_mana_changed(current_mana: float, max_mana: float, _reason: ManaComponent.Reason) -> void:
	ui_manager.set_hakubo_mana(current_mana, max_mana)

func _on_result_animation_finished(anim_name: String) -> void:
	if anim_name == "result_screen_show":
		player.set_process_to(true)

func _dialogue_init() -> void:
	if Dialogue.is_readed("first_death"):
		is_first_death = false
	else:
		is_first_death = true

func setup_ui() -> void:
	ui_manager.set_hakubo_break_bars(hakubo.killing_count)

	# 死んで戻ってきたときは 0 ではなく「その周回のここまでの累計」から再開する。
	var i := clampi(GameManager.loop_count, 0, GameManager.wave_times.size() - 1)
	ui_manager.set_time_text(GameManager.format_time(GameManager.wave_times[i]))

func _ready() -> void:
	var player_start_marker = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Markers/PlayerStartMarker as Marker2D
	var hakubo_start_marker = $CenterContainer/EffectLayer/SubViewportContainer/SubViewport/World/Markers/hakuboStartMarker as Marker2D

	player.add_collision_exception_with(hakubo)
	hakubo.add_collision_exception_with(player)

	if not player_start_marker or not hakubo_start_marker:
		push_error("PlayerStartMarker or hakuboStartMarker is missing in the scene.")
	else:
		player_start_position = player_start_marker.global_position
		hakubo_start_position = hakubo_start_marker.global_position

	battle_timer.name = "BattleTimer"
	add_child(battle_timer)
	battle_timer.ticked.connect(_on_battle_timer_ticked)

	boss_stage.battle_started.connect(_start_battle)
	GameManager.run_reset.connect(_on_run_reset)
	player.mana_component.depleted.connect(_on_player_died)
	player.mana_component.damaged.connect(_on_player_damaged)

	hakubo.defeated.connect(_on_hakubo_died)
	hakubo.mana_broken.connect(_on_hakubo_mana_broken)

	setup_ui()

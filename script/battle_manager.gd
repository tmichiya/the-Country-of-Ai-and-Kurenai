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

@onready var ui_manager: CanvasLayer = $UILayer

var battle_active: bool = true
var player_start_position: Vector2
var hakubo_start_position: Vector2

var is_first_death: bool = true

var battle_timer := BattleTimer.new()

var _timing_wave_index: int = 0


func reset_battle() -> void:
	battle_active = false
	# 前回の走りかけを持ち越さない。部屋は作り直されないので明示的に戻す。
	battle_timer.reset()
	player.global_position = player_start_position
	hakubo.global_position = hakubo_start_position
	player.reset()
	hakubo.reset()
	paint_layer.reset()
	setup_ui()

func _on_run_reset() -> void:
	is_first_death = true

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
	player.body_anim.play("reset")

func _on_player_died() -> void:
	_end_battle(false)

func _on_hakubo_died() -> void:
	_end_battle(true)

func _on_hakubo_mana_broken(killing_count: int) -> void:
	print("hakubo mana broken: %d" % killing_count)
	ui_manager.set_hakubo_break_bars(killing_count)
	ui_manager.burst_hakubo_break_bar(killing_count)

func _world_to_uv(node: Node2D) -> Vector2:
	var vp := node.get_viewport()
	var screen_pos := vp.get_canvas_transform() * node.global_position
	return screen_pos / vp.get_visible_rect().size

func _end_battle(is_win: bool) -> void:
	if not battle_active:
		return
	battle_active = false

	GameManager.add_wave_time(_timing_wave_index, battle_timer.stop())

	player.set_process_input(false)
	hakubo.set_process_to(false)
	hakubo.state = hakubo.State.IDLE
	paint_layer.clear_jobs()

	var color : Color = Effects.FLASH_AI if is_win else Effects.FLASH_KURENAI
	var target: Node2D = hakubo if is_win else player
	var uv := _world_to_uv(target)

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

		Dialogue.load_death_json()
		if is_first_death:
			is_first_death = false
			await Dialogue.play_conversation("first_death")
		else:
			await Dialogue.play_conversation("random_%d_death" % (randi() % 6 + 1))
	else:
		# hakubo dead
		Effects.slowmotion(0.15, 1.2)
		Effects.shake(5.0)
		Effects.flash_impact(color, 1.0, 0.5, uv)

	AudioManager.play_bgm(AudioManager.BGM_BATTLE_STAGE, 0.5, true)

	player.set_process_to(false)
	battle_finished.emit(is_win)

func _start_battle() -> void:
	battle_active = true
	battle_started.emit()

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

func _on_player_mana_changed(current_mana: float, max_mana: float) -> void:
	ui_manager.set_player_mana(current_mana, max_mana)

func _on_player_damaged() -> void:
	player.blowed_off((player.global_position - hakubo.global_position).normalized(), 4.0)

func _on_hakubo_mana_changed(current_mana: float, max_mana: float) -> void:
	ui_manager.set_hakubo_mana(current_mana, max_mana)

func _on_result_animation_finished(anim_name: String) -> void:
	if anim_name == "result_screen_show":
		player.set_process_to(true)

func setup_ui() -> void:
	ui_manager.set_player_mana(player.mana_component.mana, player.mana_component.max_mana)
	ui_manager.set_hakubo_mana(hakubo.mana_component.mana, hakubo.mana_component.max_mana)
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
	player.mana_component.mana_changed.connect(_on_player_mana_changed)
	player.mana_component.damaged.connect(_on_player_damaged)

	hakubo.defeated.connect(_on_hakubo_died)
	hakubo.mana_broken.connect(_on_hakubo_mana_broken)
	hakubo.mana_component.mana_changed.connect(_on_hakubo_mana_changed)

	setup_ui()

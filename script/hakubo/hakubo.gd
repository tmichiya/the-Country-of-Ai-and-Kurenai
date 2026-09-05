extends CharacterBody2D

signal attack_parried

## マナバーを1本失った（が、まだ立っている）。演出上「1本消費した」と見せる瞬間＝
## ステージ中心へ跳び上がる瞬間に発火する。HUD の残機ゲージはこれを購読して1本消す。
signal mana_broken(killing_count: int)
## 規定本数を折り切った＝本当に敗北した。戦闘終了はこれをトリガにする。
## mana_broken とは排他（最後の1本では mana_broken は飛ばず、こちらだけが飛ぶ）。
signal defeated

enum State {
	IDLE,
	WALK,
	ATTACK,
	CHAT,
	STUNNED
}

enum MovementState {
	NONE,
	DASH
}

@export var MOVE_SPEED: float = 1.0
@export var MANA: float = 100.0

## 何本マナバーを折れば撃破になるか。ここを変えるだけで 1本勝負にも 5本勝負にもできる。
@export var required_killing_count: int = 3
## --- 中間の撃破（＝まだ倒しきっていない）の演出パラメータ ---
## 倒れてから跳ぶまでに、揺れをどこまで／どれだけの時間かけて溜めるか。
@export var break_shake_strength: float = 6.0
@export var break_shake_duration: float = 1.2
## ステージ中心へ跳んで戻るときの見た目の高さと滞空時間。
@export var break_jump_height: float = 64.0
@export var break_jump_duration: float = 0.9

## 今までに折られたマナバーの本数。0 → 1 → 2 → 3。
## 「薄暮の残機」であり、この機能の主軸となる状態。
var killing_count: int = 0
## 撃破処理中フラグ。硬直中に再びカウントが進まないようにするガード。
var _is_breaking: bool = false

var state: State
var state_timer: float = 1.0
var move_speed: float = MOVE_SPEED
var movement_dash_timer: float = 0.0
var movement_state: MovementState = MovementState.NONE
var movement_state_dash_strength: float = 0
var movement_direction: float = 0.0
var attack_instance: Node2D = null
var mana: float = MANA
var anim_dir: String = "down"
var current_position: Vector2 = Vector2.ZERO
var direction: float = 0.0
var chosen_attack: String = ""
var is_jumping: bool = false

@export var battle_manager: Node2D
@export var player: CharacterBody2D
@export var paint_layer: Node2D
@export var battle_field_center_marker: Marker2D

const attack_karatake_scene: PackedScene = preload("res://scene/hakubo/attack_karatake.tscn")
const attack_onagi_scene: PackedScene = preload("res://scene/hakubo/attack_onagi.tscn")
const attack_sandankuzushi_scene: PackedScene = preload("res://scene/hakubo/attack_sandankuzushi.tscn")
const attack_jisome_scene: PackedScene = preload("res://scene/hakubo/attack_jisome.tscn")
const attack_jinrai_scene: PackedScene = preload("res://scene/hakubo/attack_jinrai.tscn")
const attack_dash_scene: PackedScene = preload("res://scene/hakubo/attack_dash_hakubo.tscn")
const attack_hyper_karatake_scene: PackedScene = preload("res://scene/hakubo/attack_hyper_karatake.tscn")
const attack_hyper_onagi_scene: PackedScene = preload("res://scene/hakubo/attack_hyper_onagi.tscn")
const attack_hyper_jisome_scene: PackedScene = preload("res://scene/hakubo/attack_hyper_jisome.tscn")
const attack_hyper_jinrai_scene: PackedScene = preload("res://scene/hakubo/attack_hyper_jinrai.tscn")
const attack_super_hyper_karatake_scene: PackedScene = preload("res://scene/hakubo/attack_super_hyper_karatake.tscn")
const attack_super_hyper_onagi_scene: PackedScene = preload("res://scene/hakubo/attack_super_hyper_onagi.tscn")
const attack_super_hyper_jisome_scene: PackedScene = preload("res://scene/hakubo/attack_super_hyper_jisome.tscn")
const attack_super_hyper_jinrai_scene: PackedScene = preload("res://scene/hakubo/attack_super_hyper_jinrai.tscn")

@onready var mana_component: ManaComponent = $ManaComponent
@onready var ai_controller: Node = $AIController
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual: Node2D = $Visual
@onready var animation_player: AnimationPlayer = $AttackVisual/AnimationPlayer
@onready var hurt_box: Area2D = $HurtBox
@onready var hit_box: CollisionShape2D = $HitBox

@onready var particle_loop1: Node2D = $Visual/Loop1
@onready var particle_loop2: Node2D = $Visual/Loop2
@onready var particle_loop_end: Node2D = $Visual/LoopEnd

# 攻撃定義の単一の真実の源（single source of truth）。
# id -> AttackData。名前・コスト・シーン・スタンス相性はすべてここ経由で参照する。
var _attack_by_id: Dictionary = {}

# 攻撃定義をコード側で一括構築する。
# ここが「攻撃を追加・調整する唯一の場所」になる。
# （将来インスペクタで編集したくなったら、各 AttackData を .tres として保存し
#  @export var attack_roster: Array[AttackData] に差し替えるだけで移行できる）
func _build_default_roster() -> void:
	_attack_by_id.clear()
	#              id                 scene                        cost  min  max  inv    mult  stance_affinity
	_register_attack("karatake",      attack_karatake_scene,       20.0,  50, 200, false, 1.0, {"OFFENSIVE": 0.9, "RETREAT": 1.3, "PAINT": 1.2, "NEUTRAL": 1.5})
	_register_attack("onagi",         attack_onagi_scene,          20.0,   0,  30, true,  1.5, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 1.5})
	_register_attack("sandankuzushi", attack_sandankuzushi_scene,  10.0,   0, 100, true,  1.0, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 0.8})
	_register_attack("jisome",        attack_jisome_scene,         10.0,   0, 150, false, 1.0, {"OFFENSIVE": 0.9, "RETREAT": 0.9, "PAINT": 1.3})
	_register_attack("jinrai",        attack_jinrai_scene,         20.0,  60, 150, false, 1.0, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 0.8})
	_register_attack("hyper_karatake", attack_hyper_karatake_scene, 20.0, 50, 200, false, 1.0, {"OFFENSIVE": 0.9, "RETREAT": 1.3, "PAINT": 1.2, "NEUTRAL": 1.5})
	_register_attack("hyper_onagi",    attack_hyper_onagi_scene,    20.0,   0,  30, true,  1.5, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 1.5})
	_register_attack("hyper_jisome",   attack_hyper_jisome_scene,   10.0,   0, 150, false, 1.0, {"OFFENSIVE": 0.9, "RETREAT": 0.9, "PAINT": 1.5})
	_register_attack("hyper_jinrai",   attack_hyper_jinrai_scene,   20.0,  60, 150, false, 1.0, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 0.8})
	_register_attack("super_hyper_karatake", attack_super_hyper_karatake_scene, 20.0, 50, 200, false, 1.0, {"OFFENSIVE": 0.9, "RETREAT": 1.3, "PAINT": 1.2, "NEUTRAL": 1.5})
	_register_attack("super_hyper_onagi",    attack_super_hyper_onagi_scene,    20.0,   0,  30, true,  1.5, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 1.5})
	_register_attack("super_hyper_jisome",   attack_super_hyper_jisome_scene,   10.0,   0, 150, false, 1.0, {"OFFENSIVE": 0.9, "RETREAT": 0.9, "PAINT": 1.5})
	_register_attack("super_hyper_jinrai",   attack_super_hyper_jinrai_scene,   20.0,  60, 150, false, 1.0, {"OFFENSIVE": 1.3, "RETREAT": 0.9, "PAINT": 0.8})

	var dash_def := _register_attack("dash", attack_dash_scene, 5.0, 0, 0, false, 1.0, {"OFFENSIVE": 1.3, "RETREAT": 2.2, "PAINT": 0.8})
	dash_def.is_dash = true

func _register_attack(id: String, scene: PackedScene, cost: float, min_range: float, max_range: float, inverted: bool, mult: float, affinity: Dictionary) -> AttackData:
	var def := AttackData.new()
	def.id = id
	def.scene = scene
	def.mana_cost = cost
	def.min_range = min_range
	def.max_range = max_range
	def.range_inverted = inverted
	def.base_multiplier = mult
	def.stance_affinity = affinity
	_attack_by_id[id] = def
	return def

# --- 外部（ai_controller / debug）向けの公開 API ---
func get_attack_ids() -> Array:
	return _attack_by_id.keys()

func get_attack_def(id: String) -> AttackData:
	return _attack_by_id.get(id, null)

var loop0_available_attacks_id: Array = ["karatake", "onagi", "sandankuzushi", "jisome", "jinrai", "dash"]
var loop1_available_attacks_id: Array = ["hyper_karatake", "hyper_onagi", "hyper_jisome", "hyper_jinrai", "dash"]
var loop2_available_attacks_id: Array = ["super_hyper_karatake", "super_hyper_onagi", "super_hyper_jisome", "super_hyper_jinrai", "dash"]
func get_availible_attack_ids() -> Array:
	var available: Array = []
	var loop_count = GameManager.loop_count
	if loop_count == 0:
		available = loop0_available_attacks_id
	elif loop_count == 1:
		available = loop1_available_attacks_id
	elif loop_count == 2:
		available = loop2_available_attacks_id
	return available

func reset() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)

	visible = true
	state = State.IDLE
	state_timer = 1.0
	killing_count = 0        # 部屋に入り直したら残機は満タンに戻す
	_is_breaking = false
	hurt_box.set_deferred("monitoring", true)
	hurt_box.set_deferred("monitorable", true)
	hit_box.disabled = false
	ai_controller.set_process(true)
	visual.position.y = 0    # break 演出のジャンプ中にリセットが来ても浮いたままにならないように
	Effects.set_can_shake_decay(true)
	move_speed = MOVE_SPEED
	movement_dash_timer = 0.0
	movement_state = MovementState.NONE
	movement_state_dash_strength = 0
	is_jumping = false   # ジャンプ中にリセットが来ても状態が残らないように
	animation_player.play("reset")
	if attack_instance:
		attack_instance.queue_free()
		attack_instance = null
	mana_component.restore(mana_component.get_max_mana())
	_set_position()
	set_physics_process(false)

	particle_loop_end.visible = false

	if GameManager.loop_count == 0:
		particle_loop1.visible = false
		particle_loop2.visible = false

		ai_controller.max_movement_speed = 80.0
	elif GameManager.loop_count == 1:
		particle_loop1.visible = true
		particle_loop2.visible = false

		ai_controller.max_movement_speed = 80.0
	elif GameManager.loop_count == 2:
		particle_loop1.visible = true
		particle_loop2.visible = true

		ai_controller.max_movement_speed = 100.0

func set_process_to(active: bool) -> void:
	set_physics_process(active)

func set_state(new_state: State) -> void:
	state = new_state

func set_direction(new_direction: float) -> void:
	direction = new_direction

func _set_sprite(pos_diff: Vector2) -> void:
	if pos_diff == Vector2.ZERO:
		if anim_dir == "down":
			animated_sprite.play("down_idle")
		elif anim_dir == "up":
			animated_sprite.play("up_idle")
		elif anim_dir == "left":
			animated_sprite.play("left_idle")
		elif anim_dir == "right":
			animated_sprite.play("right_idle")
	else:
		if direction >= -PI/4 and direction < PI/4:
			animated_sprite.play("right_walk")
			anim_dir = "right"
		elif direction >= PI/4 and direction < 3*PI/4:
			animated_sprite.play("down_walk")
			anim_dir = "down"
		elif direction >= -3*PI/4 and direction < -PI/4:
			animated_sprite.play("up_walk")
			anim_dir = "up"
		else:
			animated_sprite.play("left_walk")
			anim_dir = "left"

func _set_position() -> void:
	var start_marker = get_parent().get_node("Markers").get_node_or_null("hakuboStartMarker") as Marker2D
	if start_marker:
		global_position = start_marker.global_position
	else:
		push_error("hakuboStartMarker is missing in the scene.")

func attack(attack_id: String) -> void:
	var def: AttackData = _attack_by_id.get(attack_id, null)
	if def == null:
		push_error("Unknown attack id: %s" % attack_id)
		_on_attack_finished()
		return

	if not mana_component.can_spend(def.mana_cost):
		_on_attack_finished()
		return

	attack_instance = def.scene.instantiate()
	# dash は現在スタンスに応じて着地挙動を切り替える（生成後に解決）
	if def.is_dash:
		_apply_dash_stance(attack_instance)
		mana_component.spend(def.mana_cost)

	add_child(attack_instance)
	attack_instance.global_position = global_position
	attack_instance.paint_layer = paint_layer
	attack_instance.attack_finished.connect(_on_attack_finished)
	attack_instance.mana_cost = def.mana_cost

	if attack_instance.has_signal("parried"):
		attack_instance.parried.connect(parried)

	var anim_name := "hakubo_" + attack_id
	if animation_player.is_playing():
		animation_player.stop()
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

	set_state(State.ATTACK)

# dash 生成後に、現在スタンスへ応じた着地挙動を設定する。
# 旧仕様を踏襲: OFFENSIVE / NEUTRAL → OFFENSIVE, RETREAT / PAINT → RETREAT
func _apply_dash_stance(dash_instance: Node2D) -> void:
	var s = ai_controller.current_stance
	if s == ai_controller.AttackStance.OFFENSIVE or s == ai_controller.AttackStance.NEUTRAL:
		dash_instance.set_dash_stance(dash_instance.DashStance.OFFENSIVE)
	else:
		dash_instance.set_dash_stance(dash_instance.DashStance.RETREAT)

## height   : 見た目の跳ね上がり量（Visual を上下させるだけで、足元は動かない）
## duration : 滞空時間
## to_position : 指定すると滞空中に水平移動して、そこへ着地する。省略時はその場でジャンプ。
func jump(height: float, duration: float, to_position: Vector2 = Vector2.INF) -> void:
	is_jumping = true
	hit_box.disabled = true
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

	# 「見た目の高さ（Visual:position:y）」と「実際の足元（global_position）」は別物。
	# 高さを山なりに、水平移動をなめらかに、別トゥイーンで並行に動かすと放物線に見える。
	# CharacterBody2D は毎フレーム move_and_slide() で動くので、トゥイーンと喧嘩しないよう
	# velocity を 0 にしてから動かす。
	if to_position != Vector2.INF:
		velocity = Vector2.ZERO
		var move_tw := create_tween()
		move_tw.tween_property(self, "global_position", to_position, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tw = create_tween()
	tw.tween_property(visual, "position:y", (-1) * height, duration / 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position:y", 0, duration - duration / 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tw.finished

	hit_box.disabled = false
	hurt_box.set_deferred("monitoring", true)
	hurt_box.set_deferred("monitorable", true)
	is_jumping = false

func _on_attack_finished(state_timer_min: float = 0.0, state_timer_max: float = 1.0) -> void:
	attack_instance = null
	animation_player.play("reset")
	set_state(State.WALK)
	state_timer = randf_range(state_timer_min, state_timer_max)

func _on_loop0_post_aura() -> void:
	particle_loop1.visible = true
	Effects.set_can_shake_decay(false)
	Effects.shake(0.8)

func _on_loop0_post_end() -> void:
	particle_loop_end.visible = true
	Effects.set_can_shake_decay(false)
	Effects.shake(2.0)

func _on_loop1_post_aura() -> void:
	particle_loop2.visible = true
	Effects.set_can_shake_decay(false)
	Effects.shake(0.8)

func _on_loop1_post_end() -> void:
	particle_loop_end.visible = true
	Effects.set_can_shake_decay(false)
	Effects.shake(2.0)

func is_telegraphing() -> bool:
	if attack_instance and attack_instance.has_method("is_playing_telegraph_animation"):
		return attack_instance.is_playing_telegraph_animation()
	return false

func dash(length: float, strength: float, dir: float = 0.00) -> void:
	movement_state = MovementState.DASH
	movement_dash_timer = length
	movement_state_dash_strength = strength
	if dir != 0.00:
		movement_direction = dir
	else:
		movement_direction = direction

func rotate_towards_player() -> void:
	if player:
		var direction = Vector2(player.position.x - position.x, player.position.y - position.y).normalized()
		rotation = direction.angle()

# from_projectile: 攻撃ノード本体ではなく、そこから撃ち出された飛び道具（子ノード）
# 由来のパリィかどうか。子は親の攻撃ノードより長く生き残るため、パリィが届いた時点で
# attack_instance はすでに「次の攻撃」に差し替わっている可能性がある。
# その状態でテレグラフを解除すると無関係な攻撃を壊すので、子由来のときはスキップする。
func parried(uv: Vector2, from_projectile: bool = false) -> void:
	if not from_projectile:
		if attack_instance and attack_instance.has_method("switch_is_telegraphing_to") and attack_instance.is_playing_telegraph_animation():
			attack_instance.switch_is_telegraphing_to(false)

	attack_parried.emit()
	dash(0.5, -200.0)
	Effects.slowmotion(0, 0.12)
	Effects.shake(3.5)

	Effects.flash_impact(Effects.FLASH_WHITE, 1.0, 0.3, uv)

func get_player_distance() -> float:
	if player:
		return global_position.distance_to(player.global_position)
	return 0.0

func get_player_position() -> Vector2:
	if player:
		return player.global_position
	return Vector2.ZERO

func get_player_vector() -> Vector2:
	if player:
		return player.input_vector
	return Vector2.ZERO

# =============================================================
# 撃破カウント（killing_count）
#
# マナが 0 になるたびに _on_mana_depleted() へ来る。
#   1本目・2本目 → _play_mana_break()：硬直してマナバーを張り直す。戦闘は続行。
#   3本目        → _play_death() + defeated 発火：ここで初めて戦闘が終わる。
#
# 「マナが 0 になった」と「薄暮が死んだ」を別の概念として分けたのがこの設計の肝。
# 外（battle_manager）は mana_component.depleted ではなく defeated を見るので、
# 何本折れば死ぬかを後から変えても外側のコードは一切触らなくて済む。
# =============================================================

func _on_mana_depleted() -> void:
	# 硬直中、あるいは既に決着済みなら無視する。
	# （硬直中は無敵にしてあるが、フラグでも二重に守っておくのが安全）
	if _is_breaking or killing_count >= required_killing_count:
		return
	_is_breaking = true

	killing_count += 1
	print("hakubo mana broken: %d / %d" % [killing_count, required_killing_count])

	if killing_count >= required_killing_count:
		# 最終本。_is_breaking は true のまま残す＝以降の depleted を完全に殺す。
		_play_death()
		defeated.emit()
	else:
		# mana_broken は _play_mana_break() の中（跳ぶ瞬間）で発火する。
		await _play_mana_break(killing_count)
		_is_breaking = false


## 中間の撃破（まだ倒しきっていない）。
##   倒れる → 揺れが増していく → 最大の瞬間にステージ中心へ跳ぶ → 着地して立て直す
## 一連の演出をひとつの関数に時系列どおり並べてある。await で「次の段へ進む条件」を
## 書けるのが GDScript のコルーチンの強みで、状態変数やタイマーを増やさずに済む。
func _play_mana_break(count: int) -> void:
	# --- 1. 行動を全部止める ---
	# 進行中の攻撃を片付ける。残すと当たり判定が生き続けて多重ヒットになる。
	force_attack_to_finish()
	set_state(State.STUNNED)
	velocity = Vector2.ZERO
	# AI の思考も止める。止めないと緊急ダッシュ判定が force_attack_to_finish() を呼び、
	# その中の _on_attack_finished() が State.WALK に戻してしまい硬直が効かない。
	ai_controller.set_process(false)
	# 演出中は無敵。0 のまま殴られ続けても意味がないので判定ごと切る。
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

	# --- 2. 倒れる ---
	# 向きの判定は _play_death() と同じ規則にそろえてある（薄暮から見てプレイヤーが左右どちらか）。
	_set_sprite(Vector2.ZERO)
	var dir := (global_position - player.global_position).normalized()
	if dir.x > 0:
		animation_player.play("dead_right")
	else:
		animation_player.play("dead_left")
	AudioManager.play_se("damage")

	# --- 3. 揺れを溜める ---
	# smooth_shake は shake_strength をトゥイーンするだけ。Effects._process が毎フレーム
	# 減衰させているので、先に減衰を止めないと溜まらず打ち消されてしまう。
	Effects.set_can_shake_decay(false)
	await Effects.smooth_shake(0.0, break_shake_strength, break_shake_duration)

	# --- 4. 揺れが最大になった瞬間 ＝ 跳ぶ瞬間 ---
	# HUD の残機ゲージが1本消えるのもこのタイミング（mana_broken を購読している側が反応する）。
	mana_broken.emit(count)
	AudioManager.play_se("mana_break")
	Effects.set_can_shake_decay(true)   # ここから揺れは自然減衰に任せる
	await jump(break_jump_height, break_jump_duration, battle_field_center_marker.global_position)

	# --- 5. 着地。立て直す ---
	# マナバーを張り直す。mana_changed が飛ぶので HUD は自動で追従する。
	mana_component.restore(mana_component.get_max_mana())
	paint_layer.paint_blob(global_position, 150, paint_layer.KURENAI, Vector2.ZERO)
	animation_player.play("reset")
	hurt_box.set_deferred("monitoring", true)
	hurt_box.set_deferred("monitorable", true)
	ai_controller.set_process(true)
	set_state(State.WALK)
	state_timer = 0.5


## 最終本を折られたときの死亡演出。従来 _on_died() だったもの。
func _play_death() -> void:
	print("hakubo has died due to mana depletion.")
	var dir = (global_position - player.global_position).normalized()

	_set_sprite(Vector2.ZERO)

	dash(0.5, -1200.0, dir.angle())
	if dir.x > 0:
		animation_player.play("dead_right")
	else:
		animation_player.play("dead_left")

func _on_battle_started() -> void:
	set_physics_process(true)
	set_state(State.WALK)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name.begins_with("hakubo_"):
		animation_player.play("reset")

func force_attack_to_finish(min: float = 0.0, max: float = 0.0) -> void:
	# 攻撃を強制終了する。中断された攻撃ノードは自分では片付かない（自前のアニメ終了時にしか
	# queue_free しない）ので、ここで明示的に破棄する。残すと当たり判定が生き続けて多重ヒットになる。
	if attack_instance and is_instance_valid(attack_instance):
		attack_instance.queue_free()
	_on_attack_finished(min, max)

func _ready() -> void:
	_build_default_roster()   # 攻撃定義を最初に構築（choose_attack より前に必ず用意する）

	mana_component.set_max_mana(MANA)
	mana_component.reset()
	mana_component.depleted.connect(_on_mana_depleted)

	Dialogue.loop0_post_aura.connect(_on_loop0_post_aura)
	Dialogue.loop0_post_end.connect(_on_loop0_post_end)
	Dialogue.loop1_post_aura.connect(_on_loop1_post_aura)
	Dialogue.loop1_post_end.connect(_on_loop1_post_end)

	if battle_manager:
		battle_manager.battle_started.connect(_on_battle_started)

	velocity = Vector2.ZERO

var previous_position: Vector2 = Vector2.ZERO
func _physics_process(delta: float) -> void:

	# footstep se
	if not previous_position.is_equal_approx(global_position):
		var diff_length = (global_position - previous_position).length()
		if diff_length > 40 and not is_jumping:
			AudioManager.play_se("hakubo_footstep")
			previous_position = global_position

	if state == State.WALK:
		if player:
			direction = Vector2(player.position.x - position.x, player.position.y - position.y).angle()
			var pos_diff = global_position - current_position
			current_position = global_position

			_set_sprite(pos_diff)

		if state_timer > 0.0:
			state_timer -= delta
		else:
			if attack_instance:
				# 攻撃中は攻撃が終わるまで待つ
				print("Waiting for attack to finish...")
				return
			chosen_attack = ai_controller.choose_attack()
			if chosen_attack == "":
				print("No valid attack chosen. Remaining idle.")

			# _debug()

			print("Chosen attack: %s" % chosen_attack)

			if chosen_attack != "":
				attack(chosen_attack)
			state_timer = randf_range(1.0, 3.0)

	visual.global_rotation = 0.0 


	# 足元が敵色なら鈍足
	if not is_jumping:
		var color_at_feet = paint_layer.get_color_owner_at(global_position)
		if color_at_feet == paint_layer.AI:
			move_speed = MOVE_SPEED * 0.5
			mana_component.restore(10.0 * delta)
		elif color_at_feet == paint_layer.KURENAI:
			move_speed = MOVE_SPEED * 1.3
			mana_component.restore(20.0 * delta)
		else:
			move_speed = MOVE_SPEED
			mana_component.restore(20.0 * delta)	

	if movement_state == MovementState.DASH:
		movement_dash_timer -= delta
		if movement_dash_timer <= 0:
			movement_state = MovementState.NONE
			movement_state_dash_strength = 0
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(cos(movement_direction), sin(movement_direction)) * movement_state_dash_strength * movement_dash_timer * move_speed

	move_and_slide()

# @export var debug : Control
# func _debug() -> void:
# 	debug.display_attack_scores()

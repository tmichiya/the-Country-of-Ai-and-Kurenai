extends CharacterBody2D

signal dash_started

enum State {
	MOVE,
	DASH
}

@export var MOVE_SPEED: float = 100.0
@export var MANA: float = 100.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_speed: float = 400.0
@export var rolling_duration: float = 0.1
@export var paint_layer: Node2D

@onready var mana_component: ManaComponent = $ManaComponent
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual: Node2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox

@onready var body_anim: AnimationPlayer = $BodyAnimationPlayer

var state: State = State.MOVE
var move_speed: float = MOVE_SPEED
var normalized_input: Vector2 = Vector2.ZERO
var anim_dir: String = "down"
var dash_dir: Vector2 = Vector2.ZERO
var attack_instance: Node2D = null
var mana: float = MANA
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var input_vector: Vector2 = Vector2.ZERO

## 死亡演出中フラグ。true の間は入力を受け付けず、
## AnimatedSprite2D の差し替え（set_sprite）と damage アニメの上書きも止める。
## 「やられモーションを出した直後に damage / idle が上書きする」のを防ぐための状態。
## 吹き飛び演出は動かしたいので _physics_process 自体は止めない。
var is_dead: bool = false

## 操作をロックしている理由の集合。
##
## 【なぜ集合にするのか】
## これまでは set_process_to(true/false) を、ステージ側（カメラ演出・退場・死亡）と
## Dialogue 側（会話中は動けない）の両方が勝手に呼んでいた。
## 両者は互いを知らないので「あとから呼んだほうが勝つ」状態になり、
##   ステージ「歩き出しの3秒間は止めておいて」
##   → その最中に別の会話が終わる → Dialogue「会話終わったから動かして良いよ」
##   → 本来止まっているはずの場面でプレイヤーが動けてしまう
## という取りこぼしが起きていた。
## 「誰かひとりでもロックしている間は動けない」に変えると、
## 解除の取り違えが構造的に起こらなくなる。
var _control_locks: Dictionary = {}

const attack_dash_scene: PackedScene = preload("res://scene/player/attack_dash_player.tscn")
const attack_parry_scene: PackedScene = preload("res://scene/player/attack_parry.tscn")
const attack_rolling_scene: PackedScene = preload("res://scene/player/attack_rolling.tscn")
const attack_slash_scene: PackedScene = preload("res://scene/player/attack_slash.tscn")

func reset() -> void:
	state = State.MOVE
	move_speed = MOVE_SPEED
	dash_timer = 0.0
	dash_cd_timer = 0.0
	is_dead = false
	# 部屋に入り直したらロックは全部捨てる。
	# 前の部屋で掛かったままのロックを持ち越すと「操作できないまま始まる」事故になる。
	_control_locks.clear()
	_apply_control_locks()
	body_anim.play("reset")
	mana_component.reset()
	if attack_instance:
		attack_instance.queue_free()
		attack_instance = null
	_set_position()

# === 操作ロック ===

## 理由つきで操作を止める。同じ理由で二重に掛けても副作用はない。
func add_control_lock(reason: String) -> void:
	_control_locks[reason] = true
	_apply_control_locks()

## 掛けた理由を取り下げる。他に誰も掛けていなければ動けるようになる。
func remove_control_lock(reason: String) -> void:
	_control_locks.erase(reason)
	_apply_control_locks()

func is_control_locked() -> bool:
	return not _control_locks.is_empty()

func _apply_control_locks() -> void:
	var active := _control_locks.is_empty()
	set_process_input(active)
	set_physics_process(active)
	if not active:
		velocity = Vector2.ZERO

## 従来の呼び出し互換。ステージ側からの止め／再開は "stage" というロック名で扱う。
func set_process_to(active: bool) -> void:
	if active:
		remove_control_lock("stage")
	else:
		add_control_lock("stage")

func set_hurtbox_monitor(active: bool) -> void:
	hurtbox.set_deferred("monitorable", active)

func _set_position() -> void:
	var start_marker = get_parent().get_node("Markers").get_node_or_null("PlayerStartMarker") as Marker2D
	if start_marker:
		global_position = start_marker.global_position
	else:
		push_error("PlayerStartMarker is missing in the scene.")

func get_direction() -> float:
	return (get_global_mouse_position() - global_position).angle()

# アクション入力は Input ポーリングで処理する。
# プレイヤーは SubViewport 内にいて _input イベントが届かないことがあるため、
# 移動(Input.get_vector)と同じ方式に統一する。_physics_process から毎フレーム呼ぶ。
func _handle_actions() -> void:
	if is_dead or state != State.MOVE:
		return

	# if Input.is_action_just_pressed("dash") and dash_cd_timer <= 0:
	# 	if not mana_component.spend(10.0):
	# 		return
	# 	dash_timer = dash_duration
	# 	dash_cd_timer = dash_cooldown
	# 	dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

	# 	attack_instance = attack_dash_scene.instantiate()
	# 	add_child(attack_instance)
	# 	attack_instance.global_position = global_position

	# 	state = State.DASH
	# 	return

	if Input.is_action_just_pressed("rolling"):
		if not mana_component.spend(5.0):
			return
		dash_timer = rolling_duration
		dash_dir = normalized_input if normalized_input != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()

		attack_instance = attack_rolling_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

		dash_started.emit()

		state = State.DASH

	if Input.is_action_just_pressed("parry"):
		if not mana_component.spend(10.0):
			return
		attack_instance = attack_parry_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position
		if attack_instance.has_method("parried"):
			attack_instance.parried.connect(_on_attack_finished)
		attack_instance.attack_finished.connect(_on_attack_finished)
		attack_instance.rotation = global_position.angle_to_point(get_global_mouse_position())

	if Input.is_action_just_pressed("slash"):
		if not mana_component.spend(5.0):
			return
		if attack_instance:
			return
		attack_instance = attack_slash_scene.instantiate()
		add_child(attack_instance)
		attack_instance.global_position = global_position

func _on_attack_finished() -> void:
	if attack_instance:
		attack_instance = null
		state = State.MOVE

func blowed_off(direction: Vector2) -> void:
	dash_timer = rolling_duration * 6.0
	dash_dir = direction

	attack_instance = attack_rolling_scene.instantiate()
	add_child(attack_instance)
	attack_instance.global_position = global_position

	dash_started.emit()

	state = State.DASH

func timer_control(delta: float) -> void:
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta

func _on_died() -> void:
	print("Player has died due to mana depletion.")

# === アニメーション ===

## 被弾モーション。攻撃側から body_anim を直接叩かせず、必ずここを通す。
##
## 【なぜ必要だったか】
## ManaComponent.take_damage() は内部で depleted シグナルを“同期的に”出す。
## つまり攻撃側の
##     player.mana_component.take_damage(damage)   # ← この行の中で死亡処理が全部走る
##     player.body_anim.play("damage")             # ← やられモーションを上書きしてしまう
## という2行で、直前に再生された dead_left / dead_right が必ず消されていた。
## 「死んでいたら damage は流さない」と決めておけば、呼ぶ順番に関係なく壊れない。
func play_damage_animation() -> void:
	if is_dead:
		return
	body_anim.play("damage")

## その場の向き（anim_dir）の idle スプライトで静止させる。
##
## 【なぜ必要か】
## AnimatedSprite2D は最後に play() したアニメを再生し続ける。
## walk は 10 フレームのループアニメなので、「スプライトの差し替えをやめる」
## だけでは、倒れた姿勢のまま足だけ動き続けてしまう。
## 明示的に idle へ切り替えて止める必要がある。
##
## idle は 1 フレームなので play() だけでも実質静止するが、
## 将来 idle を複数フレームにしても静止画のままになるよう stop() まで行う
## （stop() は再生を止めたうえで frame を 0 に戻す）。
func freeze_sprite_to_idle() -> void:
	animated_sprite.play(anim_dir + "_idle")
	animated_sprite.stop()

## やられモーション。dir_x は「吹き飛ばされる向き」の x 成分。
func play_death_animation(dir_x: float) -> void:
	is_dead = true
	# 歩きアニメがループし続けないよう、まず idle で静止させる。
	# is_dead を立てると set_sprite() は何もしなくなるので、ここで明示的に行う。
	freeze_sprite_to_idle()
	if dir_x < 0.0:
		body_anim.play("dead_left")
	else:
		body_anim.play("dead_right")

func stop_movement(_t: String) -> void:
	set_sprite(Vector2.ZERO)
	add_control_lock("dialogue")

func _on_dialogue_finished(_t: String) -> void:
	# 会話が終わっても外すのは「会話ロック」だけ。
	# ステージ側が別の理由で止めているなら、そちらは効いたままになる。
	remove_control_lock("dialogue")

func set_sprite(input_vector: Vector2) -> void:
	# 死亡演出中にスプライトを差し替えると、倒れた絵が立ち絵に戻ってしまう
	if is_dead:
		return
	var direction = input_vector.angle()
	if input_vector == Vector2.ZERO:
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

func play_animation(anim_name: String) -> void:
	body_anim.play(anim_name)

func _ready() -> void:
	state = State.MOVE
	mana_component.depleted.connect(_on_died)
	Dialogue.started.connect(stop_movement)
	Dialogue.finished.connect(_on_dialogue_finished)
	Dialogue.cancelled.connect(_on_dialogue_finished)

var footstep_timer: float = 0.0
var footstep_interval: float = 0.5
func _physics_process(delta: float) -> void:
	timer_control(delta)
	_handle_actions()

	# footstep se
	footstep_timer += delta
	if state == State.MOVE:
		footstep_interval = 0.5
	elif state == State.DASH:
		footstep_interval = 0.1

	if footstep_timer >= footstep_interval and normalized_input != Vector2.ZERO:
		footstep_timer = 0.0
		AudioManager.play_se("player_footstep")

	# dash movement
	if(state == State.DASH):
		velocity = dash_dir * dash_speed

		if (dash_timer <= 0):
			if attack_instance:
				attack_instance.queue_free()
			state = State.MOVE
	
	if (state == State.MOVE and not is_dead):
		input_vector = Input.get_vector("left", "right", "up", "down")
		velocity = input_vector * move_speed
		normalized_input = input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO
		set_sprite(input_vector)

	# 足元が敵色なら鈍足
	if paint_layer:
		var color_at_feet = paint_layer.get_color_owner_at(global_position)
		if color_at_feet == paint_layer.KURENAI:
			move_speed = MOVE_SPEED * 0.5
			mana_component.restore(10.0 * delta)
		elif color_at_feet == paint_layer.AI:
			move_speed = MOVE_SPEED * 1.4
			mana_component.restore(20.0 * delta)
		else:
			move_speed = MOVE_SPEED
			mana_component.restore(20.0 * delta)

	move_and_slide()

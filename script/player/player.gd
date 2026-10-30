extends CharacterBody2D

## hakuboの緊急ダッシュ回避用シグナル
signal dash_started
signal mana_changed(current_mana: float, max_mana: float, reason: ManaComponent.Reason)
signal parried

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
@export var mana_shortage_text: Node2D

@onready var mana_component: ManaComponent = $ManaComponent
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual: Node2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox

@onready var body_anim: AnimationPlayer = $BodyAnimationPlayer
## 被弾時に体を白くする ColorRect。damage アニメが表示/非表示を切り替える。
@onready var body_flash: CanvasItem = $Visual/AnimatedSprite2D/Flash
@onready var attack_visual: Node2D = $AttackVisual
## 攻撃インスタンスに渡す、体と武器のアニメをまとめて流す部品。
@onready var attack_animation_rig: AttackAnimationRig = $AttackAnimationRig

@onready var damage_particles: Node2D = $AttackVisual/DamageParticles
@onready var parry_attack_particles: Node2D = $AttackVisual/ParryAttackParticles
@onready var regeneration_particles: Node2D = $Visual/RegenerationParticle

var state: State = State.MOVE
var move_speed: float = MOVE_SPEED
var normalized_input: Vector2 = Vector2.ZERO
var anim_dir: String = "down"
## 最後に入った移動方向。立ち止まっている間の「レイメイが向いている方向」として使う。
var facing_direction: Vector2 = Vector2.DOWN
var dash_dir: Vector2 = Vector2.ZERO
var attack_instance: Node2D = null
## いま出ているパリィ。「パリィ中か」はこの参照があるかどうかだけで決める
## （別に bool を持つと、終わり方ごとに戻し忘れが起きるため）。
var parry_instance: Node2D = null
var rolling_instance: Node2D = null
var mana: float = MANA
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var input_vector: Vector2 = Vector2.ZERO

var easy_mana_cost_multiplier: float = 1.0

var interactible_object: Node2D = null

var target_enemy : CharacterBody2D = null

## 死亡演出中フラグ。
var is_dead: bool = false

## 戦闘時以外は自然回復させる
var is_auto_regeneration_mode: bool

## 操作をロックしている理由の集合。
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
	_control_locks.clear()
	_apply_control_locks()
	body_anim.play("reset")
	freeze_sprite_to_idle()
	mana_component.reset()
	target_enemy = null
	if is_instance_valid(attack_instance):
		attack_instance.queue_free()
	attack_instance = null
	if is_instance_valid(parry_instance):
		parry_instance.queue_free()
	parry_instance = null
	_free_rolling()
	_set_position()

	if GameManager.easy_mode:
		easy_mana_cost_multiplier = 0.7
	else:
		easy_mana_cost_multiplier = 1.0

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

func set_process_to(active: bool) -> void:
	if active:
		remove_control_lock("stage")
	else:
		add_control_lock("stage")

func set_hurtbox_monitor(active: bool) -> void:
	hurtbox.set_deferred("monitorable", active)

func set_interactable(active: bool, target: Node2D) -> void:
	if active:
		interactible_object = target
	else:
		interactible_object = null

func set_target_enemy(enemy: CharacterBody2D) -> void:
	target_enemy = enemy

func set_auto_regeneration_mode(active: bool) -> void:
	is_auto_regeneration_mode = active

## パリィが出ているか。終わり方（成功・時間切れ・reset で破棄）を問わず、
## パリィがツリーから外れた時点で自動的に false になる。
func is_parrying() -> bool:
	return is_instance_valid(parry_instance) and not parry_instance.is_queued_for_deletion()

func _set_position() -> void:
	var start_marker = get_parent().get_node("Markers").get_node_or_null("PlayerStartMarker") as Marker2D
	if start_marker:
		global_position = start_marker.global_position
	else:
		push_error("PlayerStartMarker is missing in the scene.")

func get_direction() -> float:
	return InputDevice.get_aim_angle(self)

## ロールを出す方向。移動入力があればその方向、立ち止まっていれば向いている方向。
func get_facing_direction() -> Vector2:
	var move := InputDevice.get_move_direction()
	if move != Vector2.ZERO:
		return move.normalized()
	return facing_direction

func get_aim_direction() -> Vector2:
	return InputDevice.get_aim_direction(self)

func get_slash_attack_count() -> int:
	return slash_attack_count

## 攻撃方向をVec2で返す。
## ゲームパッドのときは、向いている方向を基本に、hakuboが向いている方向から90度以内にいるときだけhakuboに吸い付く。
## マウスのときは、マウスカーソルの方向を返す。
func calc_attack_direction() -> Vector2:
	if InputDevice.current_device == InputDevice.Device.GAMEPAD:
		# 基本は向いている方向（立ち止まっていても右に戻らない）
		var _attack_direction: Vector2 = get_facing_direction()
		# hakubo が向いている方向から 90 度以内にいるときだけ、hakubo に吸い付ける
		if target_enemy:
			var to_enemy: Vector2 = target_enemy.global_position - global_position
			var diff := absf(_attack_direction.angle_to(to_enemy))
			if diff <= deg_to_rad(90):
				return to_enemy.normalized()
		return _attack_direction
	elif InputDevice.current_device == InputDevice.Device.MOUSE_KEYBOARD:
		return get_aim_direction()
	else:
		push_error("Unknown input device: " + str(InputDevice.current_device))
		return get_facing_direction()


var slash_attack_count: int = 0
var slash_attack_count_reset_timer = 0
var slash_attack_count_reset_duration = 0.8
func _handle_actions() -> void:
	if is_dead or state != State.MOVE:
		return

	if Input.is_action_just_pressed("rolling"):
		# 同じキーを使用するため、インタラクトを優先
		if interactible_object:
			interactible_object.interact()
			return

		if not mana_component.spend(10.0 * easy_mana_cost_multiplier, ManaComponent.Reason.SPEND):
			AudioManager.play_se("shortage_of_mana")
			mana_shortage_text.display_text(global_position)
			return
		dash(rolling_duration, get_facing_direction())

		_spawn_rolling()

		dash_started.emit()


		# rolling animation判定（実際に転がる方向に合わせる）
		var dash_dir_angle = dash_dir.angle()
		if dash_dir_angle >= -PI/4 - PI / 8 and dash_dir_angle <= PI/4 + PI / 8:
			body_anim.play("rolling_right")
		elif absf(dash_dir_angle) >= (3.0/4.0 * PI - PI / 8) and absf(dash_dir_angle) <= PI:
			body_anim.play("rolling_left")

	if Input.is_action_just_pressed("parry"):
		if is_parrying():
			return
		if not mana_component.spend(10.0 * easy_mana_cost_multiplier, ManaComponent.Reason.SPEND):
			AudioManager.play_se("shortage_of_mana")
			mana_shortage_text.display_text(global_position)
			return
		var new_parry: Node2D = attack_parry_scene.instantiate()
		parry_instance = new_parry
		attack_instance = new_parry
		# どのインスタンスが終わったのかを渡し、後から出したものの参照を消さないようにする
		new_parry.attack_finished.connect(_on_attack_finished.bind(new_parry))
		new_parry.parried.connect(_on_parried)
		# どんな終わり方でも、ツリーから外れたら参照を外す（パリィ中フラグの戻し忘れが起きない）
		new_parry.tree_exited.connect(_on_parry_exited.bind(new_parry))
		# _ready() で使えるよう、add_child より前に渡す
		new_parry.animation_rig = attack_animation_rig
		add_child(new_parry)
		new_parry.global_position = global_position
		new_parry.rotation = get_direction()

		# play particles
		parry_attack_particles.play_particle(InputDevice.get_aim_direction(self))

	if Input.is_action_just_pressed("slash"):
		if is_instance_valid(attack_instance):
			return
		if not mana_component.spend(8.0 * easy_mana_cost_multiplier, ManaComponent.Reason.SPEND):
			AudioManager.play_se("shortage_of_mana")
			mana_shortage_text.display_text(global_position)
			return		
		var slash_instance: Node2D = attack_slash_scene.instantiate()
		attack_instance = slash_instance
		slash_instance.animation_rig = attack_animation_rig
		add_child(slash_instance)
		slash_instance.global_position = global_position
		slash_instance.attack_finished.connect(_on_attack_finished.bind(slash_instance))

		slash_attack_count = (slash_attack_count + 1) % 3
		slash_attack_count_reset_timer = 0

func dash(timer: float, direction: Vector2) -> void:
	dash_timer = timer
	dash_dir = direction
	state = State.DASH

var late_parry_window: float = 0.05
var late_damage_timer: float = 0.0
var damage_value: float = 0.0
var damage_reason: ManaComponent.Reason
var is_damaged: bool = false
## damage処理
## 内部でparry猶予を考慮
func take_damage(amount: float, reason: ManaComponent.Reason) -> void:
	if is_dead:
		return
	if late_damage_timer > 0:
		return
	is_damaged = true
	late_damage_timer = 0.0
	print("Player takes damage: ", amount, " due to reason: ", reason)
	damage_value = amount
	damage_reason = reason

## 攻撃インスタンスの終了通知。finished は終わったインスタンス自身。
func _on_attack_finished(finished: Node2D) -> void:
	if attack_instance == finished:
		attack_instance = null

## パリィがツリーから外れた。後から出したパリィの参照は消さない。
func _on_parry_exited(exited: Node2D) -> void:
	if parry_instance == exited:
		parry_instance = null
	if attack_instance == exited:
		attack_instance = null

## ロール用の判定ノードを出す。前のものが残っていれば先に片付ける。
func _spawn_rolling() -> void:
	_free_rolling()
	rolling_instance = attack_rolling_scene.instantiate()
	add_child(rolling_instance)
	rolling_instance.global_position = global_position

func _free_rolling() -> void:
	if is_instance_valid(rolling_instance):
		rolling_instance.queue_free()
	rolling_instance = null

func _on_parried() -> void:
	print("Parry successful!")
	body_anim.play("parry_particles")
	parried.emit()

	if is_damaged:
		is_damaged = false
		late_damage_timer = 0.0
		damage_value = 0.0

	Camera.camera_zoom_offset = Vector2(1.5, 1.5)
	await Camera.set_zoom_value(Camera.camera_zoom_offset + Vector2(0.5, 0.5), 0.2)
	await Camera.set_zoom_value(Camera.camera_zoom_offset - Vector2(0.5, 0.5), 0.2)

	Effects.slowmotion(0.4, 0.40)
	Effects.shake(5.0)
	Effects.flash_impact(Effects.FLASH_WHITE, 1.0, 0.3, target_enemy.global_position)

	# 暗転とは別口の「色フラッシュ」。暗転中は Effects 側で出さない。
	Effects.flash_fade(Effects.WHITE_VEC3, 0.5, 0.4, -0.5)


func _on_mana_changed(current_mana: float, max_mana: float, reason: ManaComponent.Reason) -> void:
	mana_changed.emit(current_mana, max_mana, reason)

func blowed_off(direction: Vector2, duration_mul: float = 6.0) -> void:
	dash_timer = rolling_duration * duration_mul
	dash_dir = direction

	_spawn_rolling()

	dash_started.emit()

	state = State.DASH

	damage_particles.rotation = direction.angle()
	damage_particles.play_particle()

func timer_control(delta: float) -> void:
	if dash_cd_timer > 0:
		dash_cd_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta

func _on_died() -> void:
	print("Player has died due to mana depletion.")

# === アニメーション ===

## 被弾モーション。攻撃側から body_anim を直接叩かせず、必ずここを通す。
func play_damage_animation() -> void:
	if is_dead:
		return
	body_anim.play("damage")

## その場の向き（anim_dir）の idle スプライトで静止させる。
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
		body_anim.play("reset")
		body_anim.play("dead_left")
	else:
		body_anim.play("reset")
		body_anim.play("dead_right")

func stop_movement(_t: String) -> void:
	set_sprite(Vector2.ZERO)
	add_control_lock("dialogue")

func _on_dialogue_finished(_t: String) -> void:
	# 会話が終わっても外すのは「会話ロック」だけ。
	# ステージ側が別の理由で止めているなら、そちらは効いたままになる。
	remove_control_lock("dialogue")

func _on_body_anim_started(anim_name: StringName) -> void:
	if anim_name != &"damage":
		body_flash.visible = false

func _on_body_anim_finished(anim_name: StringName) -> void:
	if anim_name == &"damage":
		body_flash.visible = false

func _on_player_damaged() -> void:
	AudioManager.play_se("player_damage")

	_force_to_stop_playing_animation()

	Effects.shake(5.0)
	Effects.flash_fade(Effects.RED_VEC3, 0.5, 0.2, 0.0)

func _force_to_stop_playing_animation() -> void:
	# ほかのanimationが再生中にやると、その時の再生の状態で止まってしまうため、stop()する
	if body_anim.is_playing():
		body_anim.stop()
	body_anim.play("reset")

## 入力されたVector2の方向を読み取り、それに合わせたスプライトを表示する。0 は anim_dir の idle を表示する。
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

func _heart_beat() -> void:
	AudioManager.play_se("heart_sound")
	Effects.shake(3.0)
	Effects.flash_fade(Effects.RED_VEC3, 0.2, 0.2, -0.2)

func _world_to_uv(node: Node2D) -> Vector2:
	var vp := node.get_viewport()
	var screen_pos := vp.get_canvas_transform() * node.global_position
	return screen_pos / vp.get_visible_rect().size

func _ready() -> void:
	state = State.MOVE
	mana_component.depleted.connect(_on_died)
	Dialogue.started.connect(stop_movement)
	Dialogue.finished.connect(_on_dialogue_finished)
	Dialogue.cancelled.connect(_on_dialogue_finished)
	mana_component.damaged.connect(_on_player_damaged)
	mana_component.mana_changed.connect(_on_mana_changed)
	# Flash を消す
	body_anim.animation_started.connect(_on_body_anim_started)
	body_anim.animation_finished.connect(_on_body_anim_finished)

var footstep_timer: float = 0.0
var footstep_interval: float = 0.5
var heart_beat_timer: float = 0.0
var heart_beat_interval: float = 1.0
var mana_restore_timer: float = 0.0
var mana_restore_interval: float = 0.5
func _physics_process(delta: float) -> void:
	# debug
	# mana_component.restore(1000.0)

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
			_free_rolling()
			state = State.MOVE
	
	if (state == State.MOVE and not is_dead):
		input_vector = InputDevice.get_move_direction()
		velocity = input_vector * move_speed
		normalized_input = input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO
		if normalized_input != Vector2.ZERO:
			facing_direction = normalized_input
		set_sprite(input_vector)

	# 足元の色によって鈍足とmana回復
	if paint_layer:
		var color_at_feet = paint_layer.get_color_owner_at(global_position)
		if color_at_feet == paint_layer.KURENAI:
			move_speed = MOVE_SPEED * 0.5
		elif color_at_feet == paint_layer.AI:
			move_speed = MOVE_SPEED * 1.4
			mana_restore_timer += delta
		else:
			move_speed = MOVE_SPEED
			# mana_restore_timer += delta

	# 一定時間ごとにマナを回復
	# 足元の色がAIのときのみmana_restore_timerが増える
	if mana_restore_timer >= mana_restore_interval:
		mana_restore_timer = 0.0
		regeneration_particles.play_particle()

		if is_auto_regeneration_mode:
			mana_component.restore(100.0, ManaComponent.Reason.REGENERATE)
		else:
			mana_component.restore(16.0, ManaComponent.Reason.REGENERATE)

	# マナ少ない場合は演出をだす
	var mana_percentage = mana_component.get_mana_percentage()
	if mana_percentage <= 0.35:
		heart_beat_timer += delta
		if heart_beat_timer >= heart_beat_interval:
			heart_beat_timer = 0.0
			heart_beat_interval = clamp(mana_percentage * 10, 0.2, 2.0)
			_heart_beat()

	# 猶予パリィ処理
	if is_damaged:
		late_damage_timer += delta
		if late_damage_timer >= late_parry_window:
			is_damaged = false
			late_damage_timer = 0.0
			mana_component.take_damage(damage_value, damage_reason)
			play_damage_animation()
			damage_value = 0.0

	# スラッシュ攻撃の連続回数リセットタイマー
	if slash_attack_count > 0:
		slash_attack_count_reset_timer += delta
		if slash_attack_count_reset_timer >= slash_attack_count_reset_duration:
			slash_attack_count = 0
			slash_attack_count_reset_timer = 0

	move_and_slide()

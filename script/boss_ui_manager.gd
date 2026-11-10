extends CanvasLayer

@onready var center_container: CenterContainer = $CenterContainer

@export var hakubo : CharacterBody2D
@export var player : CharacterBody2D

# 薄暮の「残機」ゲージ。配列は “消える順” に並べてある。
# 右（Sprite2）から先に消えるので、順番を変えたくなったらこの並びを入れ替えるだけでよい。
@onready var hakubo_mana_break_bars: Array[ColorRect] = [
	$CenterContainer/HUD/Boss/BossManaBreakBarSprite2/hakuboManaBreakBar2 as ColorRect,
	$CenterContainer/HUD/Boss/BossManaBreakBarSprite1/hakuboManaBreakBar2 as ColorRect,
]

@onready var hakubo_mana_break_bar_particles: Array[GPUParticles2D] = [
	$CenterContainer/HUD/Boss/BossManaBreakBarSprite2/dotParticles as GPUParticles2D,
	$CenterContainer/HUD/Boss/BossManaBreakBarSprite1/dotParticles as GPUParticles2D,
]

@onready var title_screen_anim: AnimationPlayer = $CenterContainer/TitleScreen/AnimationPlayer
@onready var title_screen_time_label: Label = $CenterContainer/TitleScreen/Control/Time/Label

## 戦闘タイムの表示ラベル。
@onready var time_label: Label = get_node_or_null("CenterContainer/HUD/TimeLabel") as Label

@onready var hud: Control = $CenterContainer/HUD
@onready var hakubo_main_mana_bar: ColorRect = $CenterContainer/HUD/Boss/MainManaBar

## 撃破の瞬間にメインのマナバーを光らせる色
@export var main_bar_burst_color: Color = Color(0.96, 0.95, 0.92, 1.0)
## 撃破の瞬間にメインのマナバーから散らす粒子（one_shot を想定）
@export var main_bar_burst_particles: GPUParticles2D

var player_mana_bar_max_height: float
var hakubo_mana_bar_max_width: float

var _hud_tween: Tween
var _main_bar_tween: Tween
var _main_bar_color: Color

func _ready() -> void:
	_main_bar_color = hakubo_main_mana_bar.color

## 最後の 1 本を削り切った合図。メインのマナバーを一瞬光らせ、粒に砕いて消す。
func burst_hakubo_main_bar() -> void:
	_kill_tween(_main_bar_tween)
	hakubo_main_mana_bar.scale.x = 1.0
	hakubo_main_mana_bar.color = main_bar_burst_color
	if main_bar_burst_particles:
		main_bar_burst_particles.restart()
	else:
		push_warning("boss_ui_manager: main_bar_burst_particles が未設定なので粒子は出しません")
	_main_bar_tween = create_tween().set_ignore_time_scale(true)
	_main_bar_tween.tween_property(hakubo_main_mana_bar, "modulate:a", 0.0, 0.25) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

## HUD 全体を duration 秒かけて消す（visible は触らない）。
func fade_out_hud(duration: float) -> void:
	_kill_tween(_hud_tween)
	_hud_tween = create_tween().set_ignore_time_scale(true)
	_hud_tween.tween_property(hud, "modulate:a", 0.0, duration)

## 撃破演出で変えた HUD の見た目を元に戻す。
func reset_hud_look() -> void:
	_kill_tween(_hud_tween)
	_kill_tween(_main_bar_tween)
	hud.modulate.a = 1.0
	hakubo_main_mana_bar.modulate.a = 1.0
	hakubo_main_mana_bar.color = _main_bar_color

func _kill_tween(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()

# 薄暮の残機ゲージ表示を更新する。
func set_hakubo_break_bars(broken: int) -> void:
	for i in hakubo_mana_break_bars.size():
		hakubo_mana_break_bars[i].visible = i >= broken

# 残機が折れるときのエフェクトを再生する。
func burst_hakubo_break_bar(broken: int) -> void:
	var index := broken - 1
	if index < 0 or index >= hakubo_mana_break_bar_particles.size():
		return
	hakubo_mana_break_bar_particles[index].restart()

# 戦闘タイムの表示を更新する。
func set_time_text(text: String) -> void:
	if time_label == null:
		return
	time_label.text = text

func set_title_screen_time(time: String) -> void:
	title_screen_time_label.text = time

func show_title_screen() -> void:
	title_screen_anim.play("stage_title")

var _previous_position_offset: Vector2 = Vector2.ZERO
func _process(delta: float) -> void:
	var move_input = Input.get_vector("left", "right", "up", "down")
	var ui_position_offset = move_input * 10.0 * -1.0
	if ui_position_offset != _previous_position_offset:
		var tw = create_tween()
		tw.tween_property(center_container, "offset_transform_position", ui_position_offset, 0.3)
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_EXPO)
		tw.set_parallel(true)
		_previous_position_offset = ui_position_offset
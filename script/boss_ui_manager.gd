extends CanvasLayer

@onready var player_mana_bar: ColorRect = $CenterContainer/HUD/Player/PlayerManaBar
@onready var player_mana_bar_background: ColorRect = $CenterContainer/HUD/Player/PlayerBaseBar
@onready var hakubo_mana_bar: ColorRect = $CenterContainer/HUD/Boss/hakuboManaBar
@onready var hakubo_mana_bar_background: ColorRect = $CenterContainer/HUD/Boss/hakuboBaseBar

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

var player_mana_bar_max_height: float
var hakubo_mana_bar_max_width: float

func set_player_mana(mana: float, max_mana: float) -> void:
	var target = (mana / max_mana) * player_mana_bar_max_height
	var tw = create_tween()
	tw.tween_property(player_mana_bar, "scale:x", target, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func set_hakubo_mana(mana: float, max_mana: float) -> void:
	var target = (mana / max_mana) * hakubo_mana_bar_max_width
	var tw = create_tween()
	tw.tween_property(hakubo_mana_bar, "scale:x", target, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

## 薄暮の残機ゲージ表示を更新する。
## broken = すでに折られた本数（= hakubo.killing_count）。
## 「何本目を消すか」ではなく「今いくつ折れているか」を渡す形にしてある。
## こうしておくと、リセット時に 0 を投げるだけで初期状態に戻せる（＝冪等）。
func set_hakubo_break_bars(broken: int) -> void:      # 状態
	for i in hakubo_mana_break_bars.size():
		hakubo_mana_break_bars[i].visible = i >= broken

func burst_hakubo_break_bar(broken: int) -> void:      # イベント
	var index := broken - 1
	if index < 0 or index >= hakubo_mana_break_bar_particles.size():
		return
	hakubo_mana_break_bar_particles[index].restart()

func set_title_screen_time(time: String) -> void:
	title_screen_time_label.text = time

func show_title_screen() -> void:
	title_screen_anim.play("stage_title")

func _ready() -> void:
	player_mana_bar_max_height = player_mana_bar_background.scale.y
	hakubo_mana_bar_max_width = hakubo_mana_bar_background.scale.x

class_name DefeatBanner
extends Control
## 撃破の宣言（大きな一文字＋小さな一行）を出して消す。
## 動きはステージ名の表示（boss_stage の Title / TitleScreen）と同じ作りで、AnimationPlayer の
## defeat_banner に入っている。線が伸び、文字が線の上下から出てきて、線が縮んで消える。

const ANIM_PLAY := &"defeat_banner"
const ANIM_RESET := &"RESET"

@onready var _main_label: Label = %MainLabel
@onready var _sub_label: Label = %SubLabel
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_immediately()


## 文字を差し替えてアニメを流す。消え終わるまで await できる。
func play(main_text: String, sub_text: String) -> void:
	_main_label.text = main_text
	_sub_label.text = sub_text
	_anim.play(ANIM_PLAY)
	# 途中で hide_immediately() されても戻ってこられるよう、終わりはタイマーで待つ（ポーズ中は止まる）
	await get_tree().create_timer(get_remaining_time(), false).timeout


## 流れているアニメの残り秒数。流れていなければ 0。
func get_remaining_time() -> float:
	if not _anim.is_playing() or _anim.current_animation != ANIM_PLAY:
		return 0.0
	return maxf(_anim.current_animation_length - _anim.current_animation_position, 0.0)


## 演出の中断用。その場で消して、次に流すときのために初期の姿勢へ戻す。
func hide_immediately() -> void:
	_anim.play(ANIM_RESET)
	_anim.advance(0.0)
	_anim.stop()
	visible = false

class_name StandingFigure
extends Sprite2D
## 戦わない立ち絵（エンディングの薄暮など）。
## 子に AttackWeapon を置けるよう、武器が body に求める API だけを持つ。

@export_enum("down", "up", "left", "right") var anim_dir: String = "down"

## AttackWeapon が読む。立ち絵は倒れないので常に false。
var is_dead: bool = false

func _ready() -> void:
	# AttackWeapon は body が入力を受け付けていないと idle を更新しないため
	set_process_input(true)

func get_anim_dir() -> String:
	return anim_dir

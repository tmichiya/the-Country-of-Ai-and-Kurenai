extends HakuboAttack

var angle_offset: float = 0.0

var target_position: Vector2 = Vector2.ZERO

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_hyper_karatake_child":
		finish_attack()

func shake_camera() -> void:
	Effects.shake(1.0)

func do_paint() -> void:
	if paint_layer:
		var from = get_parent().global_position
		var to = from + Vector2(cos(self.global_rotation), sin(self.global_rotation)) * 300
		paint_layer.paint_band(from, to, 30, 3)

		AudioManager.play_se("beam_shot")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	animation_player.play("attack_hyper_karatake_child")

	target_position = get_parent().get_player_position()

	AudioManager.play_se("beam_charge")

func _process(delta: float) -> void:
	rotation = (target_position - global_position).angle() + deg_to_rad(angle_offset)

# 

func _on_player_hit(player: Node) -> void:
	super(player)
	disable_hitbox()

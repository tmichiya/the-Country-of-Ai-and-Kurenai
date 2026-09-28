extends Polygon2D

@onready var mask_vp: SubViewport = $MaskViewport
@onready var content: TextureRect = $Content

func _ready() -> void:
	content.material.set_shader_parameter("mask_tex", mask_vp.get_texture())
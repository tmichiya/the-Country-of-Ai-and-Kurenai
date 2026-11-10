shader_type canvas_item;
// 残像用。テクスチャからは形（アルファ）だけを使い、色は modulate で塗りつぶす。

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

void fragment() {
	COLOR = vec4(modulate_color.rgb, texture(TEXTURE, UV).a * modulate_color.a);
}

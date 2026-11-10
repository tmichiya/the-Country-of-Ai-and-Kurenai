shader_type canvas_item;
// 薄暮の体を黒く染める。服の濃い紅だけは脈打つ紅の筋として残し、
// 外周の輪郭は暗い紅で縁取って、夜でも背景に溶けないようにする。

// 黒く染まる度合い（0〜1）
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
// 染まった先の色（#10000a）
uniform vec4 corrupt_color : source_color = vec4(0.063, 0.0, 0.039, 1.0);
// 筋として残す服の濃い紅（akane.png の (189,0,54)）
uniform vec4 vein_color : source_color = vec4(0.741, 0.0, 0.212, 1.0);
// 紅とみなす色の近さ
uniform float vein_tolerance = 0.2;
uniform float vein_pulse_speed = 3.0;
// 外周の縁取りの色と強さ
uniform vec4 rim_color : source_color = vec4(0.62, 0.06, 0.16, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.8;

varying vec4 modulate_color;

void vertex() {
	// modulate を fragment で掛け直すために取っておく
	modulate_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = mix(tex.rgb, corrupt_color.rgb, corruption * 0.9);

	float vein = 1.0 - smoothstep(vein_tolerance * 0.5, vein_tolerance, distance(tex.rgb, vein_color.rgb));
	float pulse = 0.75 + 0.25 * sin(TIME * vein_pulse_speed);
	float vein_amount = vein * smoothstep(0.2, 0.6, corruption);
	col = mix(col, vein_color.rgb * mix(1.0, pulse * 1.25, corruption), vein_amount);

	// 上下左右のどれかが透明なら外周のピクセル。TEXTURE は関数に渡せないのでここで直接読む
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	n = min(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	n = min(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = min(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	float edge = 1.0 - step(0.5, n);
	float rim = edge * smoothstep(0.3, 0.8, corruption) * rim_strength;
	col = mix(col, rim_color.rgb, rim);

	COLOR = vec4(col, tex.a) * modulate_color;
}

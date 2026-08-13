shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float edge_radius : hint_range(0.5, 6.0) = 2.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

const float BAYER4[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

float bayer4(vec2 pix) {
	ivec2 p = ivec2(mod(pix, 4.0));
	return (BAYER4[p.y * 4 + p.x] + 0.5) / 16.0;
}

const int R = 3;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));

	vec4 acc = vec4(0.0);
	float wsum = 0.0;

	for (int y = -R; y <= R; y++) {
		for (int x = -R; x <= R; x++) {
			vec2 o = vec2(float(x), float(y));
			float w = 1.0 - clamp(length(o) / (edge_radius + 1.0), 0.0, 1.0);
			if (w <= 0.0) continue;
			// CanvasGroup のテクスチャは既に事前乗算済み
			acc  += texture(TEXTURE, UV + o * texel) * w;
			wsum += w;
		}
	}

	float cov = (acc.a / max(wsum, 0.0001)) * amount;
	vec3  rgb = acc.a > 0.0001 ? acc.rgb / acc.a : vec3(0.0);

	float a = step(bayer4(FRAGCOORD.xy), cov);

	// 事前乗算アルファで出力する
	COLOR = vec4(rgb * a, a);
}
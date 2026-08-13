shader_type canvas_item;

// 色の段階数。小さいほどレトロで荒い、大きいほど滑らか
uniform int color_levels : hint_range(2, 32) = 4;
uniform float pixel_monitor_scale = 2.0;
uniform float dither_size = 1.0;

// 4x4 Bayer行列（0〜15を並べたもの。行優先で読む）
const float bayer4x4[16] = float[16](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);

float bayer_value(vec2 texel){
    int x = int(mod(texel.x, 4.0));
    int y = int(mod(texel.y, 4.0));
    return bayer4x4[y * 4 + x] / 16.0;
}

void fragment(){
    vec4 tex_col = texture(TEXTURE, UV);

    // UVを「低解像度テクスチャの何ピクセル目か」に変換する
    // ここを screen 側の座標ではなく texture 側の座標にするのが肝
    // vec2 texel = floor(FRAGCOORD.xy/(pixel_monitor_scale * dither_size));
	vec2 texel = floor(UV / (TEXTURE_PIXEL_SIZE * dither_size) );
    float threshold = bayer_value(texel);

    float levels = float(color_levels - 1);
    vec3 scaled = tex_col.rgb * levels;
    vec3 base = floor(scaled);
    vec3 frac = scaled - base;

    // 端数がBayerの閾値を超えたら1段階繰り上げる → これが網目になる
    vec3 dithered = base + step(vec3(threshold), frac);
    vec3 final_col = dithered / levels;

    COLOR = vec4(final_col, tex_col.a);
}
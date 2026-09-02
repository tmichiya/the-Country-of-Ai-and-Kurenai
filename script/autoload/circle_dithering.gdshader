shader_type canvas_item;
uniform float strength : hint_range(-1.0, 1.0) = -1.0;
uniform float dither_scale = 2.0;
uniform vec3 fade_color_rgb = vec3(0.05, 0.05, 0.05);
uniform float alpha = 1.0;

const float bayer4x4[16] = float[16](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);

float bayer_value(vec2 p){
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return bayer4x4[y*4 + x] / 16.0;
}

void fragment() {	
	vec4 flash_color = vec4(fade_color_rgb, alpha);
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

	float circle_value = (screen_size.x * 0.5 * (SCREEN_UV.x - 0.5) * (SCREEN_UV.x - 0.5)) + (screen_size.y * 0.5 * (SCREEN_UV.y - 0.5) * (SCREEN_UV.y - 0.5));
	float circle_pattern = clamp((circle_value) * 0.01, 0.0, 1.0);
	float intensity = circle_pattern + strength;   
	
	
	vec2 cell = floor(FRAGCOORD.xy / dither_scale);
	float threshold = bayer_value(cell);
	
	float a = step(threshold, intensity);
	
	if (a == 1.0) a = alpha;
	
	COLOR = vec4(flash_color.rgb, a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}

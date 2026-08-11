shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float dither_scale = 2.0;

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
	float d = distance(SCREEN_UV, vec2(0.5));

	float radial = 1.0 - smoothstep(0.0, 0.7, d);
	float cross_pattern = clamp(1.0 - abs((SCREEN_UV.x - 0.5) * (SCREEN_UV.y - 0.5)) * 30.0, 0.0, 1.0);
	float intensity = radial * cross_pattern * strength;   
	
	
	vec2 cell = floor(FRAGCOORD.xy / dither_scale);
	float threshold = bayer_value(cell) + 0.1;
	
	float a = step(threshold, intensity);
	
	COLOR = vec4(flash_color.rgb, a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}

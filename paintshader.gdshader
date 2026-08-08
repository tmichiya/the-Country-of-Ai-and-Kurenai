shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.85;

void fragment(){
	vec4 paint = texture(TEXTURE, UV);
	vec4 terrain = texture(screen_tex, SCREEN_UV);

	if(paint.a < 0.01){
		COLOR = terrain;
	}else{
		float luminance = dot(terrain.rgb, vec3(0.299, 0.587, 0.114));
		vec3 tinted = paint.rgb * (0.35 + luminance * 0.9);
		COLOR = vec4(mix(terrain.rgb, tinted, paint.a * tint_strength), terrain.a);
	}
}
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// 셀셰이딩: 빛을 2~3단계로 끊고, 림 라이트를 살짝. 힐링 게임 톤.

uniform vec4 albedo : source_color = vec4(0.9, 0.55, 0.3, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear, hint_default_white;
uniform float use_texture : hint_range(0.0, 1.0) = 0.0;
uniform float shade_1 : hint_range(0.0, 1.0) = 0.45;   // 첫 그림자 경계
uniform float shade_2 : hint_range(0.0, 1.0) = 0.15;   // 두 번째 경계
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.55, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.7, 1.0);
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_normal;

void vertex() {
	v_normal = NORMAL;
}

void fragment() {
	vec4 base = albedo;
	if (use_texture > 0.5) {
		base = texture(albedo_tex, UV) * albedo;
	}
	ALBEDO = base.rgb;
	ALPHA = base.a * alpha_mul;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > shade_1 ? 1.0 : (ndl > shade_2 ? 0.72 : 0.5);
	vec3 lit = ALBEDO * LIGHT_COLOR * ATTENUATION;
	vec3 shadow = ALBEDO * shadow_tint.rgb;
	DIFFUSE_LIGHT += mix(shadow, lit, band) * 0.9;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	DIFFUSE_LIGHT += rim_color.rgb * rim * LIGHT_COLOR * ATTENUATION;
}

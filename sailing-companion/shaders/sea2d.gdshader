shader_type canvas_item;
// 2D 셀셰이딩 바다. 원근(수평선 v=0 → 아래 v=1)을 가진 사인파 합성 높이장을 3~4단 색으로 끊고,
// 능선에 흰 거품 선, 태양 아래 세로 띠에 반사 조각을 뿌린다. 텍스처 없이 전부 절차적.

uniform float time = 0.0;
uniform float wind_norm : hint_range(0.0, 1.0) = 0.3;   // (풍속-5)/20
uniform float wind_dir_x : hint_range(-1.0, 1.0) = 0.0; // 파도 진행의 좌우 성분
uniform float gust : hint_range(0.0, 1.0) = 0.0;
uniform float sun_x : hint_range(0.0, 1.0) = 0.5;       // 태양의 화면 가로 위치(0~1)
uniform float speed_norm : hint_range(0.0, 2.0) = 0.5;  // 선속/6kn

uniform vec4 deep_color : source_color = vec4(0.427, 0.451, 0.62, 1.0);
uniform vec4 mid_color : source_color = vec4(0.486, 0.529, 0.706, 1.0);
uniform vec4 light_color : source_color = vec4(0.612, 0.655, 0.804, 1.0);
uniform vec4 crest_color : source_color = vec4(0.827, 0.855, 0.925, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 0.988, 0.965, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.847, 0.612, 1.0);
uniform vec4 sun_glow : source_color = vec4(1.0, 0.741, 0.475, 1.0);

// v(0~1)에서의 원근 압축: 수평선 근처는 파장이 촘촘하고 진폭이 작다.
float persp(float v) {
	return pow(max(v, 0.0001), 1.15);
}

float wave_height(vec2 uv) {
	float p = persp(uv.y);
	// 파도가 관찰자 쪽으로 다가온다: v 가 커질수록 위상이 앞선다
	float flow = time * (0.35 + 0.5 * wind_norm + 0.25 * speed_norm);
	float x = uv.x + wind_dir_x * uv.y * 0.35;
	float h = 0.0;
	h += sin((x * 6.0 + uv.y * 7.0) * 1.0 - flow * 2.2) * 0.55;
	h += sin((x * 10.0 - uv.y * 11.0) * 1.0 - flow * 3.1 + 1.7) * 0.3;
	h += sin((x * 17.0 + uv.y * 19.0) * 1.0 - flow * 4.6 + 3.1) * 0.15;
	h *= 0.9 + 1.0 * wind_norm + 0.5 * gust;
	return h * p;
}

void fragment() {
	vec2 uv = UV;
	float h = wave_height(uv);
	float p = persp(uv.y);

	// 4단 밴딩: 경계는 원근에 따라 살짝 넓어진다
	float b1 = -0.22 * p;
	float b2 = -0.02 * p;
	float b3 = 0.16 * p;
	vec3 col = deep_color.rgb;
	col = mix(col, mid_color.rgb, step(b1, h));
	col = mix(col, light_color.rgb, step(b2, h));
	col = mix(col, crest_color.rgb, step(b3, h));

	// 거품: 능선 최상단의 얇은 띠
	float foam_edge = 0.26 * p;
	float foam = smoothstep(foam_edge, foam_edge + 0.035 * p + 0.002, h) * (0.4 + 0.55 * wind_norm + 0.45 * gust);
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.9));

	// 태양 반사 길: 태양 아래 세로 띠. 아래로 갈수록 넓어지고, 능선에서만 밝게 빛난다.
	float band = 0.04 + 0.30 * uv.y;
	float dist = abs(uv.x - sun_x) / band;
	float road = exp(-dist * dist * 1.6);
	col = mix(col, sun_glow.rgb, clamp(road * 0.35 * (0.4 + uv.y), 0.0, 0.6));
	float glint = step(b2 + 0.05 * p, h) * road;
	col = mix(col, sun_color.rgb, clamp(glint * 0.9, 0.0, 0.95));

	// 수평선 쪽은 노을빛을 받아 따뜻하고 옅어진다(공기 원근)
	float haze = 1.0 - smoothstep(0.0, 0.42, uv.y);
	col = mix(col, sun_glow.rgb * 0.95, haze * 0.3);
	COLOR = vec4(col, 1.0);
}

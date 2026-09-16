shader_type canvas_item;
// 2D 셀셰이딩 하늘. 노을 그라디언트를 몇 단으로 끊고, 값 노이즈 fbm 으로 뭉게구름을 2~3단 색으로 그린다.
// 태양 원반과 글로우, 시간대(낮/노을/밤) 보간을 포함. 텍스처 없음.

uniform float time = 0.0;
uniform float wind_norm : hint_range(0.0, 1.0) = 0.3;
uniform float scroll = 0.0;                              // 구름 누적 스크롤(패럴랙스)
uniform float sun_x : hint_range(0.0, 1.0) = 0.5;
uniform float sun_y : hint_range(0.0, 1.0) = 0.88;       // 화면 기준(수평선 근처)
uniform float night : hint_range(0.0, 1.0) = 0.0;        // 0 = 노을, 1 = 밤
uniform float day : hint_range(0.0, 1.0) = 0.0;          // 1 = 한낮

uniform vec4 top_dusk : source_color = vec4(0.427, 0.412, 0.635, 1.0);
uniform vec4 mid_dusk : source_color = vec4(0.855, 0.635, 0.678, 1.0);
uniform vec4 low_dusk : source_color = vec4(0.988, 0.784, 0.612, 1.0);
uniform vec4 horizon_dusk : source_color = vec4(1.0, 0.878, 0.714, 1.0);
uniform vec4 top_night : source_color = vec4(0.129, 0.157, 0.314, 1.0);
uniform vec4 low_night : source_color = vec4(0.302, 0.278, 0.451, 1.0);
uniform vec4 top_day : source_color = vec4(0.427, 0.667, 0.878, 1.0);
uniform vec4 low_day : source_color = vec4(0.776, 0.882, 0.949, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 0.953, 0.902, 1.0);
uniform vec4 cloud_mid : source_color = vec4(0.965, 0.816, 0.792, 1.0);
uniform vec4 cloud_dark : source_color = vec4(0.741, 0.639, 0.714, 1.0);
uniform vec4 sun_disc : source_color = vec4(1.0, 0.969, 0.875, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	// 배경 그라디언트(단계적으로 끊는다)
	float g = uv.y;
	vec3 dusk = mix(top_dusk.rgb, mid_dusk.rgb, smoothstep(0.0, 0.55, g));
	dusk = mix(dusk, low_dusk.rgb, smoothstep(0.5, 0.85, g));
	dusk = mix(dusk, horizon_dusk.rgb, smoothstep(0.85, 1.0, g));
	vec3 nite = mix(top_night.rgb, low_night.rgb, smoothstep(0.1, 1.0, g));
	vec3 dayc = mix(top_day.rgb, low_day.rgb, smoothstep(0.0, 1.0, g));
	vec3 col = mix(mix(dusk, nite, night), dayc, day);
	// 살짝 밴딩(5단)으로 2D 느낌
	col = floor(col * 14.0 + 0.5) / 14.0;

	// 태양 글로우와 원반(밤에는 숨김)
	vec2 sun = vec2(sun_x, sun_y);
	float aspect = 1.6;
	float sd = length((uv - sun) * vec2(aspect, 1.0));
	float glow = exp(-sd * sd * 9.0) * (1.0 - night);
	col = mix(col, horizon_dusk.rgb, clamp(glow * 0.8, 0.0, 0.85));
	float disc = smoothstep(0.052, 0.046, sd) * (1.0 - night);
	col = mix(col, sun_disc.rgb, disc);

	// 구름 두 겹: 먼 구름(작고 느림) + 가까운 구름(크고 빠름)
	float far_x = uv.x * 2.4 + scroll * 0.35;
	float near_x = uv.x * 1.5 + scroll * 0.8;
	float cf = fbm(vec2(far_x, uv.y * 4.2 + 3.0));
	float cn = fbm(vec2(near_x, uv.y * 2.6));
	// 구름은 중상단에 모이게: 수평선 근처와 최상단은 옅게
	float mask_far = smoothstep(0.08, 0.35, uv.y) * (1.0 - smoothstep(0.6, 0.95, uv.y));
	float mask_near = smoothstep(0.18, 0.5, uv.y) * (1.0 - smoothstep(0.72, 1.0, uv.y));
	float thr = 0.56 - 0.06 * wind_norm;

	float f_body = smoothstep(thr, thr + 0.02, cf) * mask_far;
	vec3 far_col = mix(cloud_mid.rgb, cloud_light.rgb, step(thr + 0.09, cf));
	col = mix(col, mix(col, far_col, 0.72), f_body);

	float n_body = smoothstep(thr - 0.02, thr, cn) * mask_near;
	vec3 near_col = cloud_dark.rgb;
	near_col = mix(near_col, cloud_mid.rgb, step(thr + 0.05, cn));
	near_col = mix(near_col, cloud_light.rgb, step(thr + 0.12, cn));
	// 태양 쪽 구름 가장자리는 밝게
	near_col = mix(near_col, cloud_light.rgb, clamp(glow * 1.2, 0.0, 0.7));
	col = mix(col, near_col, n_body * 0.95);

	COLOR = vec4(col, 1.0);
}

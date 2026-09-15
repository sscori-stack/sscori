class_name Marinas
extends RefCounted
## 실제 마리나 좌표, 미리 정의된 항로 구간(육지를 피하는 웨이포인트 포함),
## 해역별 월별 계절풍 통계(온라인 바람을 못 받을 때의 폴백).
## 좌표·풍향 통계는 근사값이며 연출 목적이다.

## id → {name, name_ko, lat, lon, region}
const MARINAS := {
	"monaco": {"name": "Port Hercule, Monaco", "name_ko": "모나코 포르 에르퀼", "lat": 43.734, "lon": 7.424, "region": "ligurian"},
	"antibes": {"name": "Port Vauban, Antibes", "name_ko": "앙티브 포르 보방", "lat": 43.587, "lon": 7.128, "region": "ligurian"},
	"sttropez": {"name": "Saint-Tropez", "name_ko": "생트로페", "lat": 43.272, "lon": 6.638, "region": "ligurian"},
	"portofino": {"name": "Marina di Portofino", "name_ko": "포르토피노", "lat": 44.303, "lon": 9.210, "region": "ligurian"},
	"calvi": {"name": "Port de Calvi, Corsica", "name_ko": "코르시카 칼비", "lat": 42.567, "lon": 8.760, "region": "corsica"},
	"marseille": {"name": "Vieux-Port, Marseille", "name_ko": "마르세유 비외포르", "lat": 43.295, "lon": 5.365, "region": "provence"},
	"palma": {"name": "Palma de Mallorca", "name_ko": "팔마 데 마요르카", "lat": 39.565, "lon": 2.635, "region": "balearic"},
	"ibiza": {"name": "Marina Ibiza", "name_ko": "이비사", "lat": 38.912, "lon": 1.443, "region": "balearic"},
}

## 양방향 구간. waypoints 는 from→to 순서의 [lat, lon] 목록(육지·곶·섬 회피용).
const LEGS := [
	{"from": "monaco", "to": "antibes", "waypoints": [[43.640, 7.330]]},
	{"from": "antibes", "to": "sttropez", "waypoints": [[43.530, 7.150], [43.450, 7.000], [43.300, 6.760]]},
	{"from": "sttropez", "to": "marseille", "waypoints": [[43.050, 6.550], [42.950, 6.150], [43.020, 5.550], [43.250, 5.330]]},
	{"from": "monaco", "to": "portofino", "waypoints": []},
	{"from": "antibes", "to": "calvi", "waypoints": []},
	{"from": "sttropez", "to": "calvi", "waypoints": []},
	{"from": "calvi", "to": "portofino", "waypoints": []},
	{"from": "marseille", "to": "palma", "waypoints": [[43.100, 5.300]]},
	{"from": "palma", "to": "ibiza", "waypoints": [[39.400, 2.550], [38.950, 1.600]]},
]

const DEFAULT_LEG := 0

## 해역별 월별(1~12월) 계절풍: 풍향(바람이 불어오는 방향, 도)과 풍속(노트). 근사값.
const CLIMATOLOGY := {
	"ligurian": {
		"dir": [315, 315, 300, 180, 180, 150, 150, 150, 180, 300, 315, 315],
		"speed": [12, 12, 11, 9, 9, 8, 8, 8, 9, 11, 12, 12],
	},
	"corsica": {
		"dir": [270, 270, 270, 225, 225, 200, 200, 200, 225, 270, 270, 270],
		"speed": [13, 13, 12, 10, 10, 9, 9, 9, 10, 12, 13, 13],
	},
	"provence": {
		"dir": [320, 320, 320, 320, 300, 180, 180, 180, 300, 320, 320, 320],
		"speed": [16, 16, 15, 13, 12, 10, 10, 10, 12, 14, 16, 16],
	},
	"balearic": {
		"dir": [30, 30, 45, 90, 180, 180, 180, 180, 90, 45, 30, 30],
		"speed": [11, 11, 10, 9, 8, 8, 8, 8, 9, 10, 11, 11],
	},
}


static func get_marina(id: String) -> Dictionary:
	return MARINAS.get(id, {})


static func get_leg(index: int) -> Dictionary:
	return LEGS[clampi(index, 0, LEGS.size() - 1)]


## 구간을 진행 방향으로 펼친 좌표 목록 [출발, 웨이포인트..., 도착] (각 [lat, lon]).
static func leg_points(index: int, reversed: bool) -> Array:
	var leg: Dictionary = get_leg(index)
	var pts: Array = []
	pts.append([MARINAS[leg["from"]]["lat"], MARINAS[leg["from"]]["lon"]])
	for wp in leg["waypoints"]:
		pts.append([wp[0], wp[1]])
	pts.append([MARINAS[leg["to"]]["lat"], MARINAS[leg["to"]]["lon"]])
	if reversed:
		pts.reverse()
	return pts


static func leg_start_id(index: int, reversed: bool) -> String:
	var leg: Dictionary = get_leg(index)
	return leg["to"] if reversed else leg["from"]


static func leg_end_id(index: int, reversed: bool) -> String:
	var leg: Dictionary = get_leg(index)
	return leg["from"] if reversed else leg["to"]


## 도착 마리나에서 이어갈 수 있는 구간 목록: [{index, reversed}] (방금 온 구간 제외, 없으면 포함).
static func next_legs_from(marina_id: String, exclude_index: int = -1) -> Array:
	var result: Array = []
	var fallback: Array = []
	for i in LEGS.size():
		var leg: Dictionary = LEGS[i]
		var entry := {}
		if leg["from"] == marina_id:
			entry = {"index": i, "reversed": false}
		elif leg["to"] == marina_id:
			entry = {"index": i, "reversed": true}
		else:
			continue
		if i == exclude_index:
			fallback.append(entry)
		else:
			result.append(entry)
	return result if not result.is_empty() else fallback


## 계절풍 폴백: 해역·월(1~12)에 대한 [풍향, 풍속].
static func climatology(region: String, month: int) -> Array:
	var table: Dictionary = CLIMATOLOGY.get(region, CLIMATOLOGY["ligurian"])
	var m := clampi(month - 1, 0, 11)
	return [float(table["dir"][m]), float(table["speed"][m])]


## 두 좌표 사이 거리(해리). 짧은 구간용 등거리 근사.
static func distance_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var mid_lat := deg_to_rad((lat1 + lat2) * 0.5)
	var dx := (lon2 - lon1) * 60.0 * cos(mid_lat)
	var dy := (lat2 - lat1) * 60.0
	return sqrt(dx * dx + dy * dy)


## 총 구간 거리(해리).
static func leg_distance_nm(index: int) -> float:
	var pts := leg_points(index, false)
	var total := 0.0
	for i in range(1, pts.size()):
		total += distance_nm(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1])
	return total

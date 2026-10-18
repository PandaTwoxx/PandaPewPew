extends RefCounted
## Static map definitions. Every peer builds the same map from the same id, so nothing here is replicated.
## A map is: size, field theme, props [[kind, Rect2]], team spawns, CTF flag bases, Conquest points.

const ORDER := ["farm", "orchard", "corral"]
const POINT_RADIUS := 70.0
const POINT_NAMES := ["A", "B", "C", "D", "E"]


static func has_map(id: String) -> bool:
	return id in ORDER


static func map_name(id: String) -> String:
	return get_map(id).name


static func get_map(id: String) -> Dictionary:
	match id:
		"orchard": return _orchard()
		"corral": return _corral()
		_: return _farm()


## Spawns are [team 0 (left), team 1 (right)]; flags are [team 0 base, team 1 base].
static func _farm() -> Dictionary:
	var props: Array = [
		["barn", Rect2(1150, 90, 280, 180)],
		["hay", Rect2(500, 300, 200, 40)],
		["hay", Rect2(260, 480, 40, 160)],
		["fence", Rect2(900, 560, 16, 220)],
		["fence", Rect2(1150, 700, 260, 16)],
		["pond", Rect2(340, 660, 170, 170)],
	]
	for c in [Vector2(900, 200), Vector2(1380, 520), Vector2(140, 300), Vector2(760, 770), Vector2(680, 110)]:
		props.append(["tree", Rect2(c - Vector2(38, 38), Vector2(76, 76))])
	return {
		"name": "Farmyard",
		"size": Vector2(1600, 900),
		"theme": {"grass": Color("#6aa84f"), "path": true, "flora": 1.0},
		"props": props,
		"spawns": [
			PackedVector2Array([Vector2(80, 120), Vector2(80, 450), Vector2(90, 780), Vector2(230, 200)]),
			PackedVector2Array([Vector2(1520, 200), Vector2(1520, 450), Vector2(1520, 780), Vector2(1250, 450)]),
		],
		"flags": PackedVector2Array([Vector2(110, 560), Vector2(1490, 640)]),
		"points": PackedVector2Array([Vector2(420, 180), Vector2(800, 460), Vector2(1180, 640)]),
	}


## Mirror-symmetric trees in a staggered grid with an open middle lane.
static func _orchard() -> Dictionary:
	var w := 1800.0
	var props: Array = []
	var cols := [[420.0, 0.0], [620.0, 90.0], [820.0, 90.0]]
	for col in cols:
		var y: float = 140.0 + col[1]
		while y < 900.0:
			for x in [col[0], w - col[0]]:
				props.append(["tree", Rect2(Vector2(x, y) - Vector2(38, 38), Vector2(76, 76))])
			y += 180.0
	props.append(["fence", Rect2(200, 420, 16, 160)])
	props.append(["fence", Rect2(w - 216, 420, 16, 160)])
	props.append(["hay", Rect2(280, 120, 120, 40)])
	props.append(["hay", Rect2(w - 400, 120, 120, 40)])
	props.append(["hay", Rect2(280, 840, 120, 40)])
	props.append(["hay", Rect2(w - 400, 840, 120, 40)])
	return {
		"name": "Orchard",
		"size": Vector2(w, 1000),
		"theme": {"grass": Color("#5d9a45"), "path": false, "flora": 1.4},
		"props": props,
		"spawns": [
			PackedVector2Array([Vector2(100, 150), Vector2(100, 850), Vector2(100, 350), Vector2(100, 650)]),
			PackedVector2Array([Vector2(w - 100, 150), Vector2(w - 100, 850), Vector2(w - 100, 350), Vector2(w - 100, 650)]),
		],
		"flags": PackedVector2Array([Vector2(100, 500), Vector2(w - 100, 500)]),
		"points": PackedVector2Array([Vector2(900, 170), Vector2(900, 500), Vector2(900, 830)]),
	}


## Dirt corral: fenced pens on the flanks, hay cover in the middle, three points in a row.
static func _corral() -> Dictionary:
	var w := 1500.0
	var props: Array = []
	for r in [
		Rect2(200, 300, 16, 400),
		Rect2(350, 200, 40, 160),
		Rect2(350, 640, 40, 160),
		Rect2(560, 120, 200, 40),
		Rect2(560, 840, 200, 40),
	]:
		props.append(["fence" if r.size.x == 16 else "hay", r])
		props.append(["fence" if r.size.x == 16 else "hay", Rect2(w - r.end.x, r.position.y, r.size.x, r.size.y)])
	props.append(["hay", Rect2(690, 360, 120, 40)])
	props.append(["hay", Rect2(690, 600, 120, 40)])
	for c in [Vector2(250, 130), Vector2(250, 870), Vector2(w - 250, 130), Vector2(w - 250, 870)]:
		props.append(["tree", Rect2(c - Vector2(38, 38), Vector2(76, 76))])
	return {
		"name": "Corral",
		"size": Vector2(w, 1000),
		"theme": {"grass": Color("#b79a62"), "path": false, "flora": 0.15},
		"props": props,
		"spawns": [
			PackedVector2Array([Vector2(80, 120), Vector2(80, 500), Vector2(80, 880), Vector2(260, 500)]),
			PackedVector2Array([Vector2(w - 80, 120), Vector2(w - 80, 500), Vector2(w - 80, 880), Vector2(w - 260, 500)]),
		],
		"flags": PackedVector2Array([Vector2(90, 500), Vector2(w - 90, 500)]),
		"points": PackedVector2Array([Vector2(400, 500), Vector2(750, 500), Vector2(1100, 500)]),
	}

class_name Skylines
extends RefCounted
## Siluetas del horizonte: pueblos, ciudades, fábricas, puertos y flotas tal como se veían desde
## los campos de batalla reales. Cada función rellena unas Blocks en un marco local: x a lo
## largo del horizonte, z alejándose del campo (0 = lo más cercano) e y hacia arriba.
##
## Son evocaciones, no maquetas exactas: las agujas de Caen, las chimeneas de la acería de
## Colombelles, el Gosprom y el campanario de la catedral de Járkov, el puerto de Tobruk, el
## elevador de grano de una estación de la estepa.

const STONE := Color(0.62, 0.59, 0.52)
const CREAM := Color(0.74, 0.69, 0.58)
const SLATE := Color(0.27, 0.29, 0.33)
const TILE := Color(0.5, 0.26, 0.18)
const SOOT := Color(0.2, 0.19, 0.19)
const BRICK := Color(0.45, 0.27, 0.21)
const LOGS := Color(0.34, 0.26, 0.18)
const THATCH := Color(0.5, 0.44, 0.28)
const WHITE := Color(0.88, 0.86, 0.8)
const ADOBE := Color(0.8, 0.72, 0.58)
const ONION := Color(0.2, 0.34, 0.5)
const GOLD := Color(0.78, 0.64, 0.24)
const CONCRETE := Color(0.6, 0.6, 0.57)
const NAVY := Color(0.38, 0.42, 0.46)
const HULL := Color(0.2, 0.22, 0.25)
const KHAKI := Color(0.4, 0.4, 0.28)
const SILVER := Color(0.7, 0.72, 0.72)


static func build(name: String, b: Blocks, rng: RandomNumberGenerator) -> void:
	match name:
		"caen":
			caen(b, rng)
		"steelworks":
			steelworks(b, rng)
		"stlo":
			ruined_town(b, rng)
		"village_fr":
			village(b, rng, 0, 150.0, 14)
		"village_ru":
			village(b, rng, 2, 170.0, 12)
		"village_af":
			village(b, rng, 1, 130.0, 14)
		"station_ru":
			station(b, rng)
		"kharkov":
			kharkov(b, rng)
		"orel":
			orel(b, rng)
		"tobruk":
			tobruk(b, rng)
		"fort":
			desert_fort(b, rng)
		"bunkers":
			bunkers(b, rng)


## Caserío con su iglesia. `style`: 0 normando (piedra y pizarra, aguja), 1 del desierto (cubos
## encalados, alminar), 2 ruso (isbas de troncos, iglesia de cúpulas y un molino de viento).
static func village(b: Blocks, rng: RandomNumberGenerator, style: int, width: float, houses: int) -> void:
	for i in houses:
		var at := Vector3(rng.randf_range(-width * 0.5, width * 0.5), 0.0, rng.randf_range(0.0, width * 0.35))
		if absf(at.x) < 12.0 and at.z < 30.0:
			at.x += 22.0
		var size := Vector3(rng.randf_range(7.0, 11.0), rng.randf_range(4.0, 7.5), rng.randf_range(8.0, 14.0))
		var yaw: float = (rng.randi() % 2) * PI * 0.5 + rng.randf_range(-0.15, 0.15)
		match style:
			0:
				b.house([STONE, CREAM, CREAM.darkened(0.12)][rng.randi() % 3], [SLATE, TILE, SLATE.lightened(0.1)][rng.randi() % 3], size, at, yaw)
			1:
				size.y = rng.randf_range(3.5, 7.0)
				b.house([WHITE, ADOBE, WHITE.darkened(0.08)][rng.randi() % 3], Color(0, 0, 0, 0), size, at, yaw)
			_:
				size.y = rng.randf_range(3.0, 4.2)
				b.house([LOGS, LOGS.lightened(0.1)][rng.randi() % 2], [THATCH, THATCH.darkened(0.2), SLATE][rng.randi() % 3], size, at, yaw)
	match style:
		0:
			church(b, Vector3(0.0, 0.0, 14.0), 1.0, rng.randf() < 0.5)
			poplars(b, rng, Vector3(width * 0.3, 0.0, -6.0), 7)
		1:
			mosque(b, Vector3(0.0, 0.0, 12.0), 1.0)
			palms(b, rng, Vector3(-width * 0.3, 0.0, -4.0), 9)
		_:
			orthodox(b, Vector3(0.0, 0.0, 14.0), 1.0)
			windmill(b, Vector3(width * 0.5 + 26.0, 0.0, 6.0), rng.randf() * TAU)
			trees(b, rng, Vector3(-width * 0.25, 0.0, -8.0), 12, 40.0)


## Iglesia normanda: nave, torre y aguja de pizarra. `tall` da la aguja alta; si no, tejado de
## silla de montar (los dos remates más vistos en la región).
static func church(b: Blocks, at: Vector3, k: float, tall: bool) -> void:
	b.house(STONE, SLATE, Vector3(11.0, 11.0, 28.0) * k, at)
	b.box(STONE.darkened(0.06), Vector3(7.0, 21.0, 7.0) * k, at + Vector3(0.0, 0.0, -16.0 * k))
	if tall:
		b.spire(SLATE, 4.2 * k, 19.0 * k, at + Vector3(0.0, 21.0 * k, -16.0 * k), 8)
	else:
		b.roof(SLATE, Vector3(7.6, 6.0, 7.6) * k, at + Vector3(0.0, 21.0 * k, -16.0 * k))


## Iglesia ortodoxa: nave encalada, cúpulas de cebolla y campanario.
static func orthodox(b: Blocks, at: Vector3, k: float) -> void:
	b.house(WHITE, Color(0.24, 0.4, 0.3), Vector3(10.0, 9.0, 18.0) * k, at)
	for spot: Array in [[Vector3(0.0, 13.0, 2.0), 1.0], [Vector3(0.0, 24.0, -11.0), 0.8]]:
		var s: float = spot[1] * k
		var top: Vector3 = at + (spot[0] as Vector3) * k
		b.tube(WHITE, 2.2 * s, 4.0 * s, top)
		b.ball(ONION, Vector3(6.4, 6.0, 6.4) * s, top + Vector3(0.0, 6.0 * s, 0.0))
		b.spire(ONION, 1.6 * s, 4.5 * s, top + Vector3(0.0, 8.0 * s, 0.0), 8)
	b.box(WHITE.darkened(0.05), Vector3(6.0, 24.0, 6.0) * k, at + Vector3(0.0, 0.0, -11.0 * k))


## Mezquita de pueblo: sala encalada con cúpula y alminar.
static func mosque(b: Blocks, at: Vector3, k: float) -> void:
	b.box(WHITE, Vector3(14.0, 7.0, 14.0) * k, at)
	b.ball(WHITE.lightened(0.05), Vector3(10.0, 9.0, 10.0) * k, at + Vector3(0.0, 7.0 * k, 0.0))
	b.box(WHITE, Vector3(3.4, 22.0, 3.4) * k, at + Vector3(10.0 * k, 0.0, 6.0 * k))
	b.box(WHITE.darkened(0.1), Vector3(4.6, 0.8, 4.6) * k, at + Vector3(10.0 * k, 17.0 * k, 6.0 * k))
	b.spire(Color(0.3, 0.5, 0.42), 1.9 * k, 4.5 * k, at + Vector3(10.0 * k, 22.0 * k, 6.0 * k), 8)


## Molino de viento de la estepa: cuerpo de madera, caperuza y cuatro aspas.
static func windmill(b: Blocks, at: Vector3, yaw: float) -> void:
	b.spire(LOGS, 5.0, 26.0, at, 8)
	b.box(LOGS.darkened(0.1), Vector3(6.4, 9.0, 6.4), at)
	b.roof(THATCH.darkened(0.25), Vector3(6.0, 3.0, 7.0), at + Vector3(0.0, 12.5, 0.0), yaw)
	var face: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 4.0)
	for i in 4:
		var blade: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.25 + i * PI * 0.5)
		b._add(LOGS.lightened(0.25), Blocks._box, Transform3D(blade * Basis.from_scale(Vector3(2.2, 13.0, 0.3)), at + Vector3(0.0, 13.0, 0.0) + face + blade * Vector3(0.0, 6.5, 0.0)))


## Hilera de chopos: agujas verdes, altas y estrechas.
static func poplars(b: Blocks, rng: RandomNumberGenerator, at: Vector3, count: int) -> void:
	for i in count:
		var h: float = rng.randf_range(16.0, 24.0)
		b.ball(Color(0.13, 0.26, 0.1).lightened(rng.randf() * 0.1), Vector3(4.5, h, 4.5), at + Vector3(i * 7.0, h * 0.55, rng.randf_range(-1.5, 1.5)))


static func palms(b: Blocks, rng: RandomNumberGenerator, at: Vector3, count: int) -> void:
	for i in count:
		var spot: Vector3 = at + Vector3(rng.randf_range(-22.0, 22.0), 0.0, rng.randf_range(-8.0, 8.0))
		var h: float = rng.randf_range(8.0, 12.0)
		b.box(Color(0.36, 0.28, 0.18), Vector3(0.6, h, 0.6), spot)
		b.ball(Color(0.2, 0.36, 0.14), Vector3(7.0, 2.6, 7.0), spot + Vector3(0.0, h, 0.0))


## Arboleda: copas redondas apiñadas.
static func trees(b: Blocks, rng: RandomNumberGenerator, at: Vector3, count: int, spread: float, tone: Color = Color(0.14, 0.27, 0.1)) -> void:
	for i in count:
		var size := Vector3(rng.randf_range(8.0, 13.0), rng.randf_range(8.0, 13.0), rng.randf_range(8.0, 13.0))
		b.ball(tone.lightened(rng.randf() * 0.12), size, at + Vector3(rng.randf_range(-spread, spread), size.y * 0.55, rng.randf_range(-spread * 0.3, spread * 0.3)))


## Caen vista desde el frente: la ciudad de las cien agujas, con las dos torres y la linterna de
## Saint-Étienne (la abadía de los Hombres), la aguja de Saint-Pierre, las torres de la Trinité
## y el castillo sobre su colina.
static func caen(b: Blocks, rng: RandomNumberGenerator) -> void:
	for i in 90:
		var at := Vector3(rng.randf_range(-330.0, 330.0), 0.0, rng.randf_range(0.0, 150.0))
		var size := Vector3(rng.randf_range(9.0, 16.0), rng.randf_range(8.0, 16.0), rng.randf_range(11.0, 22.0))
		b.house([STONE, CREAM, CREAM.darkened(0.1), STONE.lightened(0.08)][rng.randi() % 4], [SLATE, SLATE.lightened(0.08), TILE.darkened(0.15)][rng.randi() % 3], size, at, (rng.randi() % 2) * PI * 0.5 + rng.randf_range(-0.2, 0.2))
	# Saint-Étienne: nave larga, dos torres de fachada con agujas y la linterna del crucero.
	var abbey := Vector3(-150.0, 0.0, 70.0)
	b.house(STONE, SLATE, Vector3(18.0, 24.0, 84.0), abbey, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		b.box(STONE.darkened(0.05), Vector3(9.0, 44.0, 9.0), abbey + Vector3(-46.0, 0.0, side * 7.0))
		b.spire(STONE.lightened(0.06), 5.0, 34.0, abbey + Vector3(-46.0, 44.0, side * 7.0), 8)
	b.box(STONE.darkened(0.05), Vector3(11.0, 36.0, 11.0), abbey + Vector3(12.0, 0.0, 0.0))
	b.spire(SLATE, 6.5, 24.0, abbey + Vector3(12.0, 36.0, 0.0), 8)
	for i in 4:
		b.spire(STONE.lightened(0.06), 1.6, 12.0, abbey + Vector3(34.0 + (i % 2) * 8.0, 24.0, (i / 2) * 10.0 - 5.0), 8)
	# Saint-Pierre: la gran aguja del centro.
	var pierre := Vector3(40.0, 0.0, 50.0)
	b.house(STONE, SLATE, Vector3(15.0, 20.0, 60.0), pierre, PI * 0.5)
	b.box(STONE.darkened(0.04), Vector3(9.0, 42.0, 9.0), pierre + Vector3(-18.0, 0.0, -12.0))
	b.spire(STONE.lightened(0.05), 5.0, 36.0, pierre + Vector3(-18.0, 42.0, -12.0), 8)
	# La Trinité (abadía de las Damas): dos torres romas.
	var trinite := Vector3(210.0, 0.0, 80.0)
	b.house(STONE, SLATE, Vector3(16.0, 20.0, 64.0), trinite, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		b.box(STONE.darkened(0.05), Vector3(9.0, 34.0, 9.0), trinite + Vector3(-36.0, 0.0, side * 7.0))
		b.roof(SLATE, Vector3(9.6, 5.0, 9.6), trinite + Vector3(-36.0, 34.0, side * 7.0))
	# El castillo ducal: murallas sobre un cerro.
	b.box(Color(0.3, 0.38, 0.2), Vector3(150.0, 12.0, 70.0), Vector3(110.0, 0.0, 120.0))
	b.box(STONE.darkened(0.1), Vector3(130.0, 9.0, 4.0), Vector3(110.0, 12.0, 88.0))
	for i in 5:
		b.tube(STONE.darkened(0.12), 5.0, 14.0, Vector3(50.0 + i * 30.0, 12.0, 88.0))
	# Otras parroquias.
	for spot: Vector3 in [Vector3(-280.0, 0.0, 40.0), Vector3(-60.0, 0.0, 110.0), Vector3(290.0, 0.0, 30.0)]:
		church(b, spot, 1.15, true)


## La acería de Colombelles (Société Métallurgique de Normandie): altos hornos, naves de dientes
## de sierra y las chimeneas desde las que se dominaba todo el frente al este de Caen.
static func steelworks(b: Blocks, rng: RandomNumberGenerator) -> void:
	for i in 5:
		var at := Vector3(-150.0 + i * 62.0, 0.0, 30.0 + (i % 2) * 34.0)
		b.box(BRICK.darkened(0.2), Vector3(56.0, 14.0, 28.0), at)
		for tooth in 6:
			b.roof(SOOT.lightened(0.12), Vector3(9.4, 5.0, 28.0), at + Vector3(-23.5 + tooth * 9.4, 14.0, 0.0))
	for i in 9:
		var at := Vector3(rng.randf_range(-190.0, 190.0), 0.0, rng.randf_range(10.0, 90.0))
		var h: float = rng.randf_range(52.0, 92.0)
		b.tube(BRICK.darkened(0.1), 2.6, h, at)
		b.tube(SOOT, 2.9, 3.0, at + Vector3(0.0, h - 3.0, 0.0))
	# Altos hornos con sus estufas y el plano inclinado de carga.
	for i in 3:
		var at := Vector3(-70.0 + i * 54.0, 0.0, 110.0)
		b.tube(SOOT.lightened(0.08), 8.0, 30.0, at)
		b.spire(SOOT.lightened(0.08), 8.0, 12.0, at + Vector3(0.0, 30.0, 0.0), 8)
		b.tube(SOOT, 2.0, 10.0, at + Vector3(0.0, 42.0, 0.0))
		for stove in 3:
			b.tube(SOOT.lightened(0.14), 3.4, 26.0, at + Vector3(14.0 + stove * 8.0, 0.0, 10.0))
			b.ball(SOOT.lightened(0.14), Vector3(6.8, 6.0, 6.8), at + Vector3(14.0 + stove * 8.0, 26.0, 10.0))
		b.box(SOOT.lightened(0.05), Vector3(3.0, 52.0, 4.0), at + Vector3(-20.0, 0.0, -2.0), 0.0, -0.5)
	b.tube(SOOT.lightened(0.2), 16.0, 24.0, Vector3(200.0, 0.0, 60.0))
	b.box(BRICK.darkened(0.25), Vector3(40.0, 24.0, 18.0), Vector3(-205.0, 0.0, 95.0))
	for i in 30:
		var at := Vector3(rng.randf_range(-260.0, 260.0), 0.0, rng.randf_range(-10.0, 14.0))
		b.house(CREAM.darkened(0.15), SLATE, Vector3(rng.randf_range(8.0, 12.0), rng.randf_range(5.0, 8.0), rng.randf_range(9.0, 14.0)), at, (rng.randi() % 2) * PI * 0.5)


## Ciudad arrasada (Saint-Lô, «la capital de las ruinas»): muros sin tejado y la iglesia de
## Notre-Dame con una de sus dos agujas caída.
static func ruined_town(b: Blocks, rng: RandomNumberGenerator) -> void:
	var char_wall := Color(0.36, 0.34, 0.31)
	for i in 70:
		var at := Vector3(rng.randf_range(-230.0, 230.0), 0.0, rng.randf_range(0.0, 120.0))
		var size := Vector3(rng.randf_range(8.0, 14.0), rng.randf_range(3.0, 11.0), rng.randf_range(9.0, 16.0))
		if rng.randf() < 0.25:
			b.house(STONE.darkened(0.15), SLATE, size, at, (rng.randi() % 2) * PI * 0.5)
		else:
			# Solo quedan paredes: dos muros en ángulo.
			b.box(char_wall.lightened(rng.randf() * 0.15), Vector3(size.x, size.y, 0.8), at + Vector3(0.0, 0.0, size.z * 0.5))
			b.box(char_wall.lightened(rng.randf() * 0.15), Vector3(0.8, size.y * rng.randf_range(0.5, 1.0), size.z), at + Vector3(size.x * 0.5, 0.0, 0.0))
	var church_at := Vector3(0.0, 0.0, 70.0)
	b.box(STONE.darkened(0.12), Vector3(16.0, 18.0, 56.0), church_at, PI * 0.5)
	b.box(STONE.darkened(0.08), Vector3(9.0, 40.0, 9.0), church_at + Vector3(-32.0, 0.0, -7.0))
	b.spire(STONE, 5.0, 26.0, church_at + Vector3(-32.0, 40.0, -7.0), 8)
	b.box(STONE.darkened(0.16), Vector3(9.0, 23.0, 9.0), church_at + Vector3(-32.0, 0.0, 7.0))


## Estación de la estepa (Ponyri, Prójorovka): elevador de grano con sus silos, depósito de
## agua, almacenes, un tren de mercancías y las isbas del poblado, con su iglesia.
static func station(b: Blocks, rng: RandomNumberGenerator) -> void:
	var grey := Color(0.56, 0.55, 0.5)
	b.box(grey, Vector3(13.0, 46.0, 13.0), Vector3(-60.0, 0.0, 40.0))
	b.roof(SOOT.lightened(0.15), Vector3(14.0, 5.0, 14.0), Vector3(-60.0, 46.0, 40.0))
	for i in 6:
		b.tube(grey.lightened(0.06), 5.0, 30.0, Vector3(-46.0 + i * 10.0, 0.0, 40.0))
	b.box(grey.darkened(0.1), Vector3(62.0, 5.0, 8.0), Vector3(-21.0, 30.0, 40.0))
	b.tube(BRICK.darkened(0.1), 2.4, 16.0, Vector3(40.0, 0.0, 26.0))
	b.tube(LOGS.darkened(0.2), 4.6, 7.0, Vector3(40.0, 16.0, 26.0))
	b.spire(SOOT.lightened(0.1), 5.0, 3.0, Vector3(40.0, 23.0, 26.0), 8)
	b.house(BRICK, SLATE, Vector3(11.0, 8.0, 40.0), Vector3(80.0, 0.0, 24.0), PI * 0.5)
	for i in 3:
		b.house(LOGS.darkened(0.1), SOOT.lightened(0.15), Vector3(14.0, 7.0, 44.0), Vector3(-130.0 - i * 4.0, 0.0, 30.0 + i * 20.0), PI * 0.5)
	for i in 14:
		b.box([BRICK.darkened(0.25), SOOT.lightened(0.1), LOGS][i % 3], Vector3(3.0, 3.6, 9.0), Vector3(-90.0 + i * 10.4, 1.0, 8.0), PI * 0.5)
	b.box(SOOT, Vector3(3.2, 4.4, 12.0), Vector3(-101.0, 1.0, 8.0), PI * 0.5)
	b.tube(SOOT, 0.9, 2.5, Vector3(-105.0, 5.0, 8.0))
	for i in 16:
		var at := Vector3(rng.randf_range(-190.0, 190.0), 0.0, rng.randf_range(60.0, 130.0))
		b.house(LOGS, [THATCH, THATCH.darkened(0.2)][rng.randi() % 2], Vector3(rng.randf_range(7.0, 10.0), rng.randf_range(3.0, 4.0), rng.randf_range(8.0, 12.0)), at, (rng.randi() % 2) * PI * 0.5)
	orthodox(b, Vector3(150.0, 0.0, 70.0), 1.0)
	trees(b, rng, Vector3(-170.0, 0.0, 0.0), 10, 30.0)


## Járkov: los bloques de hormigón del Gosprom unidos por pasarelas, el campanario de la
## catedral de la Asunción, fábricas y barrios de casas bajas.
static func kharkov(b: Blocks, rng: RandomNumberGenerator) -> void:
	for i in 110:
		var at := Vector3(rng.randf_range(-420.0, 420.0), 0.0, rng.randf_range(0.0, 200.0))
		var tall: bool = rng.randf() < 0.3
		var size := Vector3(rng.randf_range(12.0, 26.0), rng.randf_range(14.0, 24.0) if tall else rng.randf_range(5.0, 10.0), rng.randf_range(12.0, 30.0))
		if tall:
			b.box([CONCRETE.darkened(0.1), BRICK.lightened(0.1), CREAM.darkened(0.2)][rng.randi() % 3], size, at, (rng.randi() % 2) * PI * 0.5)
		else:
			b.house([CREAM.darkened(0.15), LOGS, BRICK][rng.randi() % 3], [SLATE, SOOT.lightened(0.2), TILE.darkened(0.2)][rng.randi() % 3], size, at, (rng.randi() % 2) * PI * 0.5)
	# Gosprom: tres grupos de torres escalonadas, con pasarelas a media altura.
	var gosprom := Vector3(-170.0, 0.0, 120.0)
	var heights: Array[float] = [34.0, 46.0, 30.0, 40.0, 58.0, 40.0, 30.0, 46.0, 34.0]
	for i in heights.size():
		b.box(CONCRETE, Vector3(22.0, heights[i], 26.0), gosprom + Vector3(-112.0 + i * 28.0, 0.0, (i % 3 - 1) * 8.0))
		if i > 0:
			b.box(CONCRETE.darkened(0.08), Vector3(8.0, 4.0, 6.0), gosprom + Vector3(-126.0 + i * 28.0, 22.0, 0.0))
	# Campanario de la catedral de la Asunción: cuerpos decrecientes y cúpula dorada.
	var tower := Vector3(150.0, 0.0, 90.0)
	b.box(WHITE.darkened(0.06), Vector3(16.0, 30.0, 16.0), tower)
	b.box(WHITE, Vector3(11.0, 26.0, 11.0), tower + Vector3(0.0, 30.0, 0.0))
	b.tube(WHITE, 4.0, 16.0, tower + Vector3(0.0, 56.0, 0.0))
	b.ball(GOLD, Vector3(9.0, 9.0, 9.0), tower + Vector3(0.0, 75.0, 0.0))
	b.spire(GOLD, 1.2, 9.0, tower + Vector3(0.0, 78.0, 0.0), 8)
	b.house(WHITE.darkened(0.05), Color(0.24, 0.4, 0.3), Vector3(20.0, 18.0, 40.0), tower + Vector3(34.0, 0.0, 0.0), PI * 0.5)
	b.ball(ONION.lightened(0.1), Vector3(14.0, 13.0, 14.0), tower + Vector3(34.0, 30.0, 0.0))
	for i in 7:
		var at := Vector3(rng.randf_range(200.0, 430.0), 0.0, rng.randf_range(30.0, 160.0))
		var h: float = rng.randf_range(40.0, 70.0)
		b.tube(BRICK.darkened(0.15), 2.4, h, at)
		b.box(BRICK.darkened(0.25), Vector3(50.0, 12.0, 22.0), at + Vector3(16.0, 0.0, 10.0))
	for spot: Vector3 in [Vector3(-380.0, 0.0, 60.0), Vector3(20.0, 0.0, 150.0), Vector3(320.0, 0.0, 20.0)]:
		orthodox(b, spot, 1.3)


## Oriol: ciudad de provincias a orillas del Oká, de casas bajas y muchas iglesias.
static func orel(b: Blocks, rng: RandomNumberGenerator) -> void:
	for i in 80:
		var at := Vector3(rng.randf_range(-320.0, 320.0), 0.0, rng.randf_range(0.0, 150.0))
		var size := Vector3(rng.randf_range(9.0, 18.0), rng.randf_range(4.0, 11.0), rng.randf_range(10.0, 22.0))
		b.house([CREAM.darkened(0.12), LOGS, WHITE.darkened(0.12), BRICK][rng.randi() % 4], [SOOT.lightened(0.2), Color(0.24, 0.4, 0.3), TILE.darkened(0.2)][rng.randi() % 3], size, at, (rng.randi() % 2) * PI * 0.5)
	for spot: Array in [[Vector3(-220.0, 0.0, 60.0), 1.5], [Vector3(-40.0, 0.0, 90.0), 1.9], [Vector3(130.0, 0.0, 40.0), 1.3], [Vector3(260.0, 0.0, 100.0), 1.6]]:
		orthodox(b, spot[0], spot[1])
	for i in 3:
		var at := Vector3(rng.randf_range(-300.0, 300.0), 0.0, rng.randf_range(100.0, 160.0))
		b.tube(BRICK.darkened(0.15), 2.2, rng.randf_range(34.0, 52.0), at)
	trees(b, rng, Vector3(0.0, 0.0, -14.0), 26, 300.0)


## Tobruk: la ciudad blanca sobre su bahía, con la iglesia italiana, un alminar, los depósitos
## del puerto, las grúas y los cascos medio hundidos en la rada.
static func tobruk(b: Blocks, rng: RandomNumberGenerator) -> void:
	for i in 80:
		var at := Vector3(rng.randf_range(-240.0, 240.0), 0.0, rng.randf_range(0.0, 110.0))
		var size := Vector3(rng.randf_range(8.0, 16.0), rng.randf_range(4.0, 10.0), rng.randf_range(8.0, 16.0))
		b.box([WHITE, WHITE.darkened(0.07), ADOBE.lightened(0.12)][rng.randi() % 3], size, at, rng.randf_range(-0.2, 0.2))
	# Iglesia de la plaza, con su campanil.
	b.house(WHITE, TILE.lightened(0.1), Vector3(12.0, 12.0, 30.0), Vector3(-40.0, 0.0, 50.0), PI * 0.5)
	b.box(WHITE.darkened(0.04), Vector3(6.0, 26.0, 6.0), Vector3(-58.0, 0.0, 50.0))
	b.spire(TILE.lightened(0.1), 3.6, 6.0, Vector3(-58.0, 26.0, 50.0))
	mosque(b, Vector3(90.0, 0.0, 40.0), 1.2)
	# Depósitos de combustible y almacenes del muelle.
	for i in 4:
		b.tube(SILVER.darkened(0.15), 9.0, 10.0, Vector3(160.0 + (i % 2) * 22.0, 0.0, 120.0 + (i / 2) * 22.0))
	for i in 3:
		b.house(ADOBE, SOOT.lightened(0.3), Vector3(16.0, 8.0, 46.0), Vector3(-150.0 + i * 54.0, 0.0, 132.0), PI * 0.5)
	palms(b, rng, Vector3(0.0, 0.0, -6.0), 14)


## Fuerte del desierto (Bir Hakeim): un viejo fortín de adobe, con sus aljibes, en mitad de la nada.
static func desert_fort(b: Blocks, rng: RandomNumberGenerator) -> void:
	b.box(ADOBE.darkened(0.08), Vector3(60.0, 7.0, 44.0), Vector3.ZERO)
	b.box(ADOBE.lightened(0.05), Vector3(52.0, 7.4, 36.0), Vector3(0.0, 0.2, 0.0))
	for x: float in [-30.0, 30.0]:
		for z: float in [-22.0, 22.0]:
			b.box(ADOBE.darkened(0.12), Vector3(9.0, 11.0, 9.0), Vector3(x, 0.0, z))
	b.box(WHITE.darkened(0.1), Vector3(3.0, 16.0, 3.0), Vector3(0.0, 7.0, 0.0))
	for i in 3:
		b.ball(ADOBE.lightened(0.1), Vector3(12.0, 5.0, 12.0), Vector3(50.0 + i * 16.0, 0.5, rng.randf_range(-10.0, 10.0)))


## Casamatas del Muro Atlántico en la costa, con sus cañones mudos.
static func bunkers(b: Blocks, rng: RandomNumberGenerator) -> void:
	var grey: Color = CONCRETE.darkened(0.2).lerp(Color(0.5, 0.46, 0.36), 0.3)
	for i in 5:
		var at := Vector3(-260.0 + i * 130.0 + rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(0.0, 14.0))
		# Medio enterradas en la duna: un morro bajo con la tronera hacia el mar.
		b.ball(Color(0.6, 0.56, 0.42), Vector3(40.0, 7.0, 26.0), at + Vector3(0.0, 0.0, -4.0))
		b.box(grey, Vector3(13.0, 4.2, 10.0), at)
		b.box(grey.lightened(0.06), Vector3(15.0, 0.9, 12.0), at + Vector3(0.0, 4.2, 0.0))
		b.box(SOOT, Vector3(6.0, 1.4, 0.6), at + Vector3(0.0, 1.6, 5.0))
		b.box(SOOT, Vector3(0.5, 0.5, 6.0), at + Vector3(0.0, 2.1, 7.0))
	# Erizos y estacas de la playa.
	for i in 60:
		var at := Vector3(rng.randf_range(-420.0, 420.0), 0.0, rng.randf_range(22.0, 34.0))
		b.box(SOOT.lightened(0.1), Vector3(0.3, 2.6, 0.3), at, rng.randf() * TAU, 0.6)
		b.box(SOOT.lightened(0.1), Vector3(0.3, 2.6, 0.3), at, rng.randf() * TAU, -0.6)


# ---------------------------------------------------------------- en el mar

## Barco: `kind` 0 carguero (tipo Liberty), 1 destructor, 2 acorazado o crucero, 3 lancha de
## desembarco. `list` (grados) lo escora, como un casco hundido en el fondo.
static func ship(b: Blocks, at: Vector3, yaw: float, kind: int, list: float = 0.0) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var tilt: float = deg_to_rad(list)
	match kind:
		0:
			b.box(HULL, Vector3(130.0, 9.0, 17.0), at, yaw, tilt)
			b.box(NAVY.lightened(0.15), Vector3(26.0, 9.0, 14.0), at + turn * Vector3(4.0, 9.0, 0.0), yaw, tilt)
			b.tube(HULL.lightened(0.1), 2.4, 8.0, at + turn * Vector3(2.0, 18.0, 0.0))
			for x: float in [-42.0, -18.0, 34.0]:
				b.box(KHAKI.darkened(0.3), Vector3(0.9, 16.0, 0.9), at + turn * Vector3(x, 9.0, 0.0))
		1:
			b.box(NAVY, Vector3(110.0, 5.0, 11.0), at, yaw)
			b.box(NAVY.lightened(0.08), Vector3(26.0, 7.0, 8.0), at + turn * Vector3(-14.0, 5.0, 0.0), yaw)
			b.tube(NAVY.darkened(0.15), 2.0, 7.0, at + turn * Vector3(4.0, 5.0, 0.0))
			b.tube(NAVY.darkened(0.15), 2.0, 6.0, at + turn * Vector3(18.0, 5.0, 0.0))
			b.box(NAVY.darkened(0.25), Vector3(0.6, 15.0, 0.6), at + turn * Vector3(-16.0, 12.0, 0.0))
			for x: float in [-40.0, 40.0]:
				b.box(NAVY.darkened(0.1), Vector3(7.0, 2.6, 5.0), at + turn * Vector3(x, 5.0, 0.0), yaw)
		2:
			b.box(NAVY.darkened(0.08), Vector3(220.0, 8.0, 30.0), at, yaw)
			b.box(NAVY, Vector3(60.0, 9.0, 20.0), at + turn * Vector3(0.0, 8.0, 0.0), yaw)
			b.box(NAVY.lightened(0.06), Vector3(16.0, 20.0, 14.0), at + turn * Vector3(-16.0, 17.0, 0.0), yaw)
			b.tube(NAVY.darkened(0.2), 4.5, 12.0, at + turn * Vector3(8.0, 17.0, 0.0))
			b.box(NAVY.darkened(0.3), Vector3(0.9, 22.0, 0.9), at + turn * Vector3(-16.0, 37.0, 0.0))
			for x: float in [-78.0, -56.0, 62.0]:
				b.box(NAVY.darkened(0.12), Vector3(18.0, 5.0, 14.0), at + turn * Vector3(x, 8.0, 0.0), yaw)
				b.box(NAVY.darkened(0.3), Vector3(20.0, 1.0, 1.0), at + turn * Vector3(x - signf(x) * 16.0, 11.0, 0.0), yaw)
		_:
			b.box(NAVY.darkened(0.1), Vector3(34.0, 4.0, 9.0), at, yaw)
			b.box(NAVY.lightened(0.05), Vector3(7.0, 4.0, 8.0), at + turn * Vector3(-12.0, 4.0, 0.0), yaw)
			b.box(NAVY.darkened(0.25), Vector3(1.0, 6.0, 9.0), at + turn * Vector3(17.0, 0.0, 0.0), yaw, -0.5)


## Globo cautivo de barrera, con su cable hasta el suelo.
static func balloon(b: Blocks, at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	b.ball(SILVER, Vector3(22.0, 8.5, 8.5), at, yaw)
	for fin: Vector3 in [Vector3(0.0, 4.0, 0.0), Vector3(0.0, -2.0, 4.0), Vector3(0.0, -2.0, -4.0)]:
		b.ball(SILVER.darkened(0.12), Vector3(8.0, 4.5, 4.5), at + turn * (Vector3(-10.0, 0.0, 0.0) + fin), yaw)
	b.box(SOOT, Vector3(0.25, at.y - 4.0, 0.25), Vector3(at.x, 0.0, at.z))


## Puerto artificial de Arromanches: el rompeolas de cajones de hormigón, los muelles flotantes
## sobre sus pilotes y las calzadas flotantes que llegan hasta la playa.
static func mulberry(b: Blocks, rng: RandomNumberGenerator, shore: float) -> void:
	for i in 18:
		var x: float = -760.0 + i * 88.0
		b.box(CONCRETE.darkened(0.08), Vector3(70.0, 9.0, 18.0), Vector3(x, 0.0, shore + 820.0 - absf(x) * 0.25 + rng.randf_range(-12.0, 12.0)), rng.randf_range(-0.08, 0.08))
	for pier: float in [-190.0, 60.0, 300.0]:
		for i in 3:
			var head := Vector3(pier + i * 66.0, 0.0, shore + 430.0)
			b.box(NAVY.lightened(0.1), Vector3(60.0, 3.0, 18.0), head + Vector3(0.0, 1.5, 0.0))
			for corner in 4:
				b.box(SOOT.lightened(0.1), Vector3(1.8, 26.0, 1.8), head + Vector3(-26.0 + (corner % 2) * 52.0, 0.0, -7.0 + (corner / 2) * 14.0))
		var spans: int = 18
		for i in spans:
			var z: float = shore + 6.0 + i * (410.0 / spans)
			b.box(SOOT.lightened(0.18), Vector3(4.0, 0.8, 410.0 / spans + 0.5), Vector3(pier, 2.2, z))
			if i % 2 == 0:
				b.box(CONCRETE.darkened(0.2), Vector3(12.0, 1.8, 5.0), Vector3(pier, 0.2, z))

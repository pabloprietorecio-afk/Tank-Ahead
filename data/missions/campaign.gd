class_name Campaign
## Misiones del modo historia: cuatro por frente y bando. En «mezcla» se alternan los frentes.
## Tipos: assault (destruir una fuerza enemiga), destroy (volar depósitos), defend (resistir en
## una posición) y boss (abatir al comandante enemigo y su escolta).

const DATA: Dictionary = {
	Fronts.Id.NORMANDY: {
		Fronts.Faction.ALLIES: [
			{"title": "TRAS LA PLAYA", "type": "assault", "count": 5, "allies": 2,
				"briefing": "Junio de 1944. Hemos salido de la playa y los setos del bocage esconden blindados alemanes. Limpia la zona para que avance la infantería."},
			{"title": "DEPÓSITOS DE CAEN", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Los alemanes acumulan combustible y munición a las afueras de Caen. Destruye los tres depósitos antes de que lleguen sus refuerzos."},
			{"title": "EL PUENTE", "type": "defend", "time": 150, "allies": 2,
				"briefing": "Hemos tomado un cruce vital. Resiste el contraataque alemán durante dos minutos y medio hasta que llegue el apoyo."},
			{"title": "CAZA AL TIGRE", "type": "boss", "count": 3, "allies": 2,
				"briefing": "Un comandante alemán con un carro pesado está frenando nuestro avance. Encuéntralo y destrúyelo junto a su escolta."},
		],
		Fronts.Faction.AXIS: [
			{"title": "CONTRAATAQUE", "type": "assault", "count": 5, "allies": 2,
				"briefing": "Junio de 1944. Los aliados han desembarcado. Contraataca y destruye sus primeras columnas de blindados entre los setos."},
			{"title": "SUMINISTROS ALIADOS", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Los aliados descargan suministros cerca del frente. Destruye los tres depósitos para frenar su ofensiva."},
			{"title": "DEFENDER LA ALDEA", "type": "defend", "time": 150, "allies": 2,
				"briefing": "La aldea controla la carretera de Caen. Mantén la posición durante dos minutos y medio frente a la ofensiva aliada."},
			{"title": "EL COMANDANTE", "type": "boss", "count": 3, "allies": 2,
				"briefing": "Un comandante aliado dirige el asalto desde un carro pesado. Abátelo y la ofensiva se detendrá."},
		],
	},
	Fronts.Id.AFRICA: {
		Fronts.Faction.ALLIES: [
			{"title": "PATRULLA EN EL DESIERTO", "type": "assault", "count": 4, "allies": 1,
				"briefing": "Desierto libio. Una avanzadilla del Afrika Korps se ha adelantado. Encuéntrala y destrúyela."},
			{"title": "COMBUSTIBLE ENEMIGO", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Sin combustible no hay ofensiva. Destruye los tres depósitos de bidones del enemigo junto al oasis."},
			{"title": "LA LÍNEA", "type": "defend", "time": 150, "allies": 2,
				"briefing": "Hemos fortificado una posición con sacos terreros. Resiste el asalto de los blindados enemigos."},
			{"title": "EL ZORRO DEL DESIERTO", "type": "boss", "count": 3, "allies": 2,
				"briefing": "El comandante enemigo dirige la ofensiva en persona desde un carro pesado. Destrúyelo."},
		],
		Fronts.Faction.AXIS: [
			{"title": "AVANCE SOBRE TOBRUK", "type": "assault", "count": 4, "allies": 1,
				"briefing": "Desierto libio. Los blindados británicos protegen el camino a Tobruk. Ábrete paso."},
			{"title": "DEPÓSITOS BRITÁNICOS", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "El enemigo guarda combustible y munición en el oasis. Destruye los tres depósitos."},
			{"title": "EL PASO", "type": "defend", "time": 150, "allies": 2,
				"briefing": "Controlamos un paso entre las dunas. Resiste el contraataque hasta que lleguen refuerzos."},
			{"title": "LA COLUMNA", "type": "boss", "count": 3, "allies": 2,
				"briefing": "Un comandante enemigo encabeza una columna blindada. Destrúyelo para romper su ataque."},
		],
	},
	Fronts.Id.KURSK: {
		Fronts.Faction.ALLIES: [
			{"title": "LA ESTEPA ARDE", "type": "assault", "count": 6, "allies": 2,
				"briefing": "Julio de 1943, Kursk. La mayor batalla de carros de la historia empieza. Detén a la vanguardia alemana."},
			{"title": "TRAS LAS LÍNEAS", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Los alemanes reabastecen a sus pesados en una aldea. Destruye los tres depósitos."},
			{"title": "PROJOROVKA", "type": "defend", "time": 180, "allies": 3,
				"briefing": "Los Tiger avanzan hacia la aldea. Resiste tres minutos: nuestra reserva está en camino."},
			{"title": "EL ELEFANTE", "type": "boss", "count": 4, "allies": 2,
				"briefing": "Un cazacarros gigante destroza nuestras columnas desde lejos. Acércate por los flancos y acaba con él."},
		],
		Fronts.Faction.AXIS: [
			{"title": "OPERACIÓN CIUDADELA", "type": "assault", "count": 6, "allies": 2,
				"briefing": "Julio de 1943, Kursk. Rompe las primeras defensas soviéticas en la estepa."},
			{"title": "DEPÓSITOS SOVIÉTICOS", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Los soviéticos han escondido combustible y munición en una aldea. Destrúyelos."},
			{"title": "LA COTA", "type": "defend", "time": 180, "allies": 3,
				"briefing": "Hemos tomado una cota. Los T-34 contraatacan en masa: resiste tres minutos."},
			{"title": "EL PESADO SOVIÉTICO", "type": "boss", "count": 4, "allies": 2,
				"briefing": "Un comandante soviético en un carro pesado lidera el contraataque. Destrúyelo."},
		],
	},
}


static func missions(faction: int, front_choice: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if front_choice == GameSession.FRONT_MIXED:
		# Mezcla: misión 1 de cada frente, luego la 2 de cada frente...
		for i in 4:
			for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
				list.append(_entry(front, faction, i))
	else:
		for i in 4:
			list.append(_entry(front_choice, faction, i))
	return list


static func _entry(front: int, faction: int, index: int) -> Dictionary:
	var mission: Dictionary = DATA[front][faction][index].duplicate()
	mission["front"] = front
	return mission

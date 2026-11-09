class_name Campaign
## Misiones del modo historia: cinco por frente y bando. En «mezcla» se alternan los frentes.
## Tipos: assault (destruir una fuerza enemiga), destroy (volar depósitos), sabotage (destruir un
## complejo: aeródromo, puerto, central, fábrica o cuartel general), defend (resistir en una
## posición), boss (abatir al comandante) y liberate (derribar las alambradas de un campo).

const DATA: Dictionary = {
	Fronts.Id.NORMANDY: {
		Fronts.Faction.ALLIES: [
			{"title": "TRAS LA PLAYA", "type": "assault", "count": 5, "allies": 2,
				"briefing": "Junio de 1944. Hemos salido de la playa y los setos del bocage esconden blindados alemanes. Limpia la zona para que avance la infantería."},
			{"title": "EL AERÓDROMO DE CARPIQUET", "type": "sabotage", "target": "airfield", "allies": 1,
				"briefing": "Julio de 1944. El aeródromo de Carpiquet, junto a Caen, sigue en manos alemanas. Destruye hangares, torre de control y aviones."},
			{"title": "EL PUENTE", "type": "defend", "time": 150, "allies": 2,
				"briefing": "Hemos tomado un cruce vital. Resiste el contraataque alemán durante dos minutos y medio hasta que llegue el apoyo."},
			{"title": "LA ACERÍA DE COLOMBELLES", "type": "sabotage", "target": "factory", "allies": 2,
				"briefing": "Desde las chimeneas de la acería de Colombelles los alemanes observan todo el frente de Caen. Destruye las naves, la chimenea y el depósito de agua."},
			{"title": "CAZA AL TIGRE", "type": "boss", "count": 3, "allies": 2,
				"briefing": "Un comandante alemán con un carro pesado está frenando nuestro avance. Encuéntralo y destrúyelo junto a su escolta."},
		],
		Fronts.Faction.AXIS: [
			{"title": "CONTRAATAQUE", "type": "assault", "count": 5, "allies": 2,
				"briefing": "Junio de 1944. Los aliados han desembarcado. Contraataca y destruye sus primeras columnas de blindados entre los setos."},
			{"title": "EL PUERTO ARTIFICIAL", "type": "sabotage", "target": "port", "allies": 1,
				"briefing": "Los aliados descargan tropas y material en un puerto artificial. Hunde el mercante y destruye grúas y almacén."},
			{"title": "DEFENDER LA ALDEA", "type": "defend", "time": 150, "allies": 2,
				"briefing": "La aldea controla la carretera de Caen. Mantén la posición durante dos minutos y medio frente a la ofensiva aliada."},
			{"title": "SUMINISTROS ALIADOS", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Los aliados acumulan combustible y munición cerca del frente. Destruye los tres depósitos."},
			{"title": "EL COMANDANTE", "type": "boss", "count": 3, "allies": 2,
				"briefing": "Un comandante aliado dirige el asalto desde un carro pesado. Abátelo y la ofensiva se detendrá."},
		],
	},
	Fronts.Id.AFRICA: {
		Fronts.Faction.ALLIES: [
			{"title": "PATRULLA EN EL DESIERTO", "type": "assault", "count": 4, "allies": 1,
				"briefing": "Desierto libio. Una avanzadilla enemiga se ha adelantado. Encuéntrala y destrúyela."},
			{"title": "COMBUSTIBLE ENEMIGO", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Sin combustible no hay ofensiva. Destruye los tres depósitos de bidones del enemigo junto al oasis."},
			{"title": "LA LÍNEA", "type": "defend", "time": 150, "allies": 2,
				"briefing": "Hemos fortificado una posición con sacos terreros. Resiste el asalto de los blindados enemigos."},
			{"title": "EL PUERTO DE SUMINISTRO", "type": "sabotage", "target": "port", "allies": 2,
				"briefing": "El enemigo recibe sus suministros por mar. Hunde el mercante del puerto y destruye grúas y almacén."},
			{"title": "EL COMANDANTE DEL DESIERTO", "type": "boss", "count": 3, "allies": 2,
				"briefing": "El comandante enemigo dirige la ofensiva en persona desde un carro pesado. Destrúyelo."},
		],
		Fronts.Faction.AXIS: [
			{"title": "AVANCE SOBRE TOBRUK", "type": "assault", "count": 4, "allies": 1,
				"briefing": "Desierto libio. Los blindados británicos protegen el camino a Tobruk. Ábrete paso."},
			{"title": "EL AERÓDROMO BRITÁNICO", "type": "sabotage", "target": "airfield", "allies": 1,
				"briefing": "Los aviones británicos atacan nuestras columnas desde un aeródromo del desierto. Destruye hangares, torre y aviones."},
			{"title": "EL PASO", "type": "defend", "time": 150, "allies": 2,
				"briefing": "Controlamos un paso entre las dunas. Resiste el contraataque hasta que lleguen refuerzos."},
			{"title": "EL CUARTEL GENERAL", "type": "sabotage", "target": "hq", "allies": 2,
				"briefing": "Hemos localizado el cuartel general británico. Destruye el búnker de mando, la antena, los barracones y el combustible."},
			{"title": "LA COLUMNA", "type": "boss", "count": 3, "allies": 2,
				"briefing": "Un comandante enemigo encabeza una columna blindada. Destrúyelo para romper su ataque."},
		],
	},
	Fronts.Id.KURSK: {
		Fronts.Faction.ALLIES: [
			{"title": "LA ESTEPA ARDE", "type": "assault", "count": 6, "allies": 2,
				"briefing": "Julio de 1943, Kursk. La mayor batalla de carros de la historia empieza. Detén a la vanguardia alemana."},
			{"title": "EL PUESTO DE MANDO", "type": "sabotage", "target": "hq", "allies": 1,
				"briefing": "Los partisanos han localizado un puesto de mando alemán. Destruye el búnker, la antena, los barracones y el combustible."},
			{"title": "PROJOROVKA", "type": "defend", "time": 180, "allies": 3,
				"briefing": "Los Tiger avanzan hacia la aldea. Resiste tres minutos: nuestra reserva está en camino."},
			{"title": "EL ELEFANTE", "type": "boss", "count": 4, "allies": 2,
				"briefing": "Un cazacarros gigante destroza nuestras columnas desde lejos. Acércate por los flancos y acaba con él."},
			{"title": "LA LIBERACIÓN", "type": "liberate", "count": 8, "allies": 2,
				"briefing": "1944. Nuestra ofensiva ha llegado a un campo de prisioneros. Derriba las alambradas para abrir paso. No dispares contra los barracones: dentro hay personas."},
		],
		Fronts.Faction.AXIS: [
			{"title": "OPERACIÓN CIUDADELA", "type": "assault", "count": 6, "allies": 2,
				"briefing": "Julio de 1943, Kursk. Rompe las primeras defensas soviéticas en la estepa."},
			{"title": "LA CENTRAL ELÉCTRICA", "type": "sabotage", "target": "power_plant", "allies": 1,
				"briefing": "Una central eléctrica abastece las fábricas y defensas soviéticas de la zona. Destruye la sala de turbinas, las chimeneas y los transformadores."},
			{"title": "LA COTA", "type": "defend", "time": 180, "allies": 3,
				"briefing": "Hemos tomado una cota. Los T-34 contraatacan en masa: resiste tres minutos."},
			{"title": "DEPÓSITOS SOVIÉTICOS", "type": "destroy", "count": 3, "allies": 1,
				"briefing": "Los soviéticos han escondido combustible y munición en una aldea. Destrúyelos."},
			{"title": "EL PESADO SOVIÉTICO", "type": "boss", "count": 4, "allies": 2,
				"briefing": "Un comandante soviético en un carro pesado lidera el contraataque. Destrúyelo."},
		],
	},
}

const PER_CAMPAIGN: int = 5


static func missions(faction: int, front_choice: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if front_choice == GameSession.FRONT_MIXED:
		# Mezcla: misión 1 de cada frente, luego la 2 de cada frente...
		for i in PER_CAMPAIGN:
			for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
				list.append(_entry(front, faction, i))
	else:
		for i in PER_CAMPAIGN:
			list.append(_entry(front_choice, faction, i))
	return list


static func _entry(front: int, faction: int, index: int) -> Dictionary:
	var mission: Dictionary = DATA[front][faction][index].duplicate()
	mission["front"] = front
	return mission

class_name Campaign
## Misiones del modo historia: ocho por frente y bando.
## Tipos: assault (destruir una fuerza enemiga), destroy (volar depósitos), sabotage (destruir un
## complejo: aeródromo, puerto, central, fábrica o cuartel general), defend (resistir en una
## posición), boss (abatir al comandante), liberate (derribar las alambradas de un campo) y
## breakthrough (cruzar las líneas enemigas hasta el otro extremo del mapa). Y sink (hundir a
## cañonazos `needed` de los `count` barcos que intentan salir del puerto).
##
## Las tres últimas de cada lista recrean combates reales; fechas y lugares están contrastados.
## Van al final, y no en orden cronológico, para no descolocar el progreso ya guardado.
## `map` es el trazado del campo (ver Layouts): el río, el pueblo, la vía o las trincheras del
## sitio real, hasta donde llega el juego. `dug_in` y `overwatch` (asaltos) son carros enemigos
## que no salen a buscar al jugador: atrincherados en pozos de tirador o en apoyo desde lejos.
## `backdrop` es el paisaje de fuera del campo (ver Backdrop): hacia qué lado queda el mar, qué
## ciudad o fábrica se ve en el horizonte y cuánto humo hay. El jugador sale del sur y avanza
## hacia el norte: «el mar al sur» es tener la playa a la espalda.
## Los tanques de cada frente son una aproximación (ver Fronts): no siempre coinciden con los
## modelos exactos que lucharon en cada batalla.

const DATA: Dictionary = {
	Fronts.Id.NORMANDY: {
		Fronts.Faction.ALLIES: [
			{"title": "TRAS LA PLAYA", "type": "assault", "count": 5, "allies": 2, "map": "coast", "backdrop": {"sea": "s", "sea_extras": ["fleet", "balloons", "landing"], "skyline": {"s": "bunkers"}, "smoke": 4},
				"briefing": "Junio de 1944. Hemos salido de la playa y los setos del bocage esconden blindados alemanes. Limpia la zona para que avance la infantería."},
			{"title": "EL AERÓDROMO DE CARPIQUET", "type": "sabotage", "target": "airfield", "allies": 1, "map": "plain_village", "backdrop": {"skyline": {"e": "caen"}, "smoke": 3},
				"briefing": "Julio de 1944. El aeródromo de Carpiquet, junto a Caen, sigue en manos alemanas. Destruye hangares, torre de control y aviones."},
			{"title": "EL PUENTE", "type": "defend", "time": 150, "allies": 2, "map": "bridge", "backdrop": {"skyline": {"n": "village_fr"}},
				"briefing": "Hemos tomado un cruce vital. Resiste el contraataque alemán durante dos minutos y medio hasta que llegue el apoyo."},
			{"title": "LA ACERÍA DE COLOMBELLES", "type": "sabotage", "target": "factory", "allies": 2, "map": "river", "backdrop": {"skyline": {"n": "steelworks", "w": "caen"}, "smoke": 4},
				"briefing": "Desde las chimeneas de la acería de Colombelles los alemanes observan todo el frente de Caen. Destruye las naves, la chimenea y el depósito de agua."},
			{"title": "CAZA AL TIGRE", "type": "boss", "count": 3, "allies": 2, "map": "bocage_dense", "backdrop": {"skyline": {"w": "village_fr"}, "smoke": 3},
				"briefing": "Un comandante alemán con un carro pesado está frenando nuestro avance. Encuéntralo y destrúyelo junto a su escolta."},
			{"title": "OPERACIÓN GOODWOOD", "type": "assault", "count": 6, "allies": 3, "map": "plain_village", "backdrop": {"skyline": {"w": "steelworks"}, "smoke": 7, "villages": 4},
				"briefing": "18 de julio de 1944. Tres divisiones acorazadas británicas atacan al este de Caen hacia la cresta de Bourguébus, defendida por blindados y cañones alemanes. Destruye los carros que la protegen."},
			{"title": "OPERACIÓN COBRA", "type": "breakthrough", "allies": 2, "map": "town", "backdrop": {"skyline": {"e": "stlo"}, "smoke": 6},
				"briefing": "25 de julio de 1944. El Primer Ejército estadounidense rompe el frente alemán al oeste de Saint-Lô y se abre camino hacia Avranches. Cruza las líneas enemigas y alcanza la salida, al norte."},
			{"title": "LA COTA 262", "type": "defend", "time": 180, "allies": 3, "map": "ridge", "backdrop": {"relief": "hills", "skyline": {"s": "village_fr"}, "smoke": 8},
				"briefing": "19 de agosto de 1944. La 1.ª División Blindada polaca ha ocupado el monte Ormel, la cota 262, y cierra la salida de la bolsa de Falaise. Los alemanes atacan desde dentro y desde fuera para reabrirla. Resiste tres minutos."},
		],
		Fronts.Faction.AXIS: [
			{"title": "CONTRAATAQUE", "type": "assault", "count": 5, "allies": 2, "map": "coast", "backdrop": {"sea": "n", "sea_extras": ["fleet", "balloons", "landing"], "smoke": 4},
				"briefing": "Junio de 1944. Los aliados han desembarcado. Contraataca y destruye sus primeras columnas de blindados entre los setos."},
			{"title": "EL PUERTO ARTIFICIAL", "type": "sabotage", "target": "port", "allies": 1, "map": "bocage", "backdrop": {"sea": "n", "sea_extras": ["mulberry", "balloons"], "skyline": {"e": "village_fr"}, "smoke": 2},
				"briefing": "Los aliados descargan tropas y material en un puerto artificial. Hunde el mercante y destruye grúas y almacén."},
			{"title": "DEFENDER LA ALDEA", "type": "defend", "time": 150, "allies": 2, "map": "town_center",
				"briefing": "La aldea controla la carretera de Caen. Mantén la posición durante dos minutos y medio frente a la ofensiva aliada."},
			{"title": "SUMINISTROS ALIADOS", "type": "destroy", "count": 3, "allies": 1, "map": "bocage_dense", "backdrop": {"skyline": {"n": "village_fr"}, "smoke": 2},
				"briefing": "Los aliados acumulan combustible y munición cerca del frente. Destruye los tres depósitos."},
			{"title": "EL COMANDANTE", "type": "boss", "count": 3, "allies": 2, "map": "bocage", "backdrop": {"skyline": {"e": "village_fr"}, "smoke": 3},
				"briefing": "Un comandante aliado dirige el asalto desde un carro pesado. Abátelo y la ofensiva se detendrá."},
			{"title": "VILLERS-BOCAGE", "type": "assault", "count": 6, "allies": 1, "map": "town", "backdrop": {"skyline": {"w": "village_fr"}, "smoke": 4},
				"briefing": "13 de junio de 1944. La vanguardia de la 7.ª División Acorazada británica ha entrado en Villers-Bocage. Una compañía de Tiger la espera junto a la cota 213. Embosca a la columna y destrúyela."},
			{"title": "LA COTA 112", "type": "defend", "time": 180, "allies": 2, "map": "ridge", "backdrop": {"skyline": {"e": "caen"}, "smoke": 5},
				"briefing": "10 de julio de 1944. Los británicos lanzan la operación Júpiter para tomar la cota 112, al suroeste de Caen: desde ella se domina toda la llanura. Mantén la colina durante tres minutos."},
			{"title": "OPERACIÓN LÜTTICH", "type": "breakthrough", "allies": 2, "map": "river", "backdrop": {"relief": "hills", "skyline": {"n": "village_fr"}, "smoke": 4},
				"briefing": "7 de agosto de 1944. Contraataque desde Mortain hacia Avranches para cortar en dos el avance estadounidense. Atraviesa sus líneas y alcanza la salida, al norte."},
		],
	},
	Fronts.Id.AFRICA: {
		Fronts.Faction.ALLIES: [
			{"title": "PATRULLA EN EL DESIERTO", "type": "assault", "count": 4, "allies": 1, "map": "wadi",
				"briefing": "Desierto libio. Una avanzadilla enemiga se ha adelantado. Encuéntrala y destrúyela."},
			{"title": "COMBUSTIBLE ENEMIGO", "type": "destroy", "count": 3, "allies": 1, "solo": true, "map": "oasis", "backdrop": {"villages": 1},
				"briefing": "Sin combustible no hay ofensiva. Destruye los tres depósitos de bidones del enemigo junto al oasis."},
			{"title": "LA LÍNEA", "type": "defend", "time": 150, "allies": 2, "map": "alamein", "backdrop": {"sea": "n"},
				"briefing": "Hemos fortificado una posición con sacos terreros. Resiste el asalto de los blindados enemigos."},
			{"title": "EL PUERTO DE SUMINISTRO", "type": "sabotage", "target": "port", "allies": 2, "map": "town", "backdrop": {"sea": "n", "sea_extras": ["harbor"], "skyline": {"e": "village_af"}, "smoke": 2},
				"briefing": "El enemigo recibe sus suministros por mar. Hunde el mercante del puerto y destruye grúas y almacén."},
			{"title": "EL COMANDANTE DEL DESIERTO", "type": "boss", "count": 3, "allies": 2, "map": "ridge",
				"briefing": "El comandante enemigo dirige la ofensiva en persona desde un carro pesado. Destrúyelo."},
			{"title": "SIDI REZEGH", "type": "sabotage", "target": "airfield", "allies": 2, "map": "ridge",
				"briefing": "19 de noviembre de 1941, operación Crusader. La 7.ª Brigada Acorazada británica cae por sorpresa sobre el aeródromo de Sidi Rezegh, camino de la sitiada Tobruk. Destruye hangares, torre de control y los aviones que no han podido despegar."},
			{"title": "ALAM EL HALFA", "type": "defend", "time": 180, "allies": 3, "map": "ridge",
				"briefing": "30 de agosto de 1942. Rommel lanza su última ofensiva en Egipto. Montgomery ha atrincherado sus carros en la cresta de Alam el Halfa y los usa como cañones contracarro. Resiste tres minutos sin ceder la cresta."},
			{"title": "OPERACIÓN SUPERCHARGE", "type": "breakthrough", "allies": 3, "map": "box", "backdrop": {"sea": "n", "relief": "flat", "smoke": 5},
				"briefing": "2 de noviembre de 1942, segunda batalla de El Alamein. El 8.º Ejército lanza el golpe final contra la línea del Eje, hacia Tel el Aqqaqir. Cruza las defensas enemigas y alcanza la salida, al norte."},
		],
		Fronts.Faction.AXIS: [
			{"title": "AVANCE SOBRE TOBRUK", "type": "assault", "count": 4, "allies": 1, "map": "wadi", "backdrop": {"sea": "n", "sea_extras": ["harbor"], "skyline": {"n": "tobruk"}, "smoke": 3},
				"briefing": "Desierto libio. Los blindados británicos protegen el camino a Tobruk. Ábrete paso."},
			{"title": "EL AERÓDROMO BRITÁNICO", "type": "sabotage", "target": "airfield", "allies": 1, "solo": true, "map": "desert",
				"briefing": "Los aviones británicos atacan nuestras columnas desde un aeródromo del desierto. Destruye hangares, torre y aviones."},
			{"title": "EL PASO", "type": "defend", "time": 150, "allies": 2, "map": "ridge", "backdrop": {"sea": "e"},
				"briefing": "Controlamos un paso entre las dunas. Resiste el contraataque hasta que lleguen refuerzos."},
			{"title": "EL PUERTO DE TOBRUK", "type": "sink", "count": 7, "needed": 5, "allies": 2, "map": "harbour", "backdrop": {"sea": "n", "sea_extras": ["harbor", "quay"], "skyline": {"e": "village_af"}, "smoke": 5},
				"briefing": "20 de junio de 1942. Los panzer han roto el perímetro de Tobruk y bajan hacia el puerto. Una cañonera y seis transportes británicos intentan escapar cargados de tropas. Ábrete paso hasta la rada y hunde al menos cinco a cañonazos antes de que ganen mar abierto."},
			{"title": "LA COLUMNA", "type": "boss", "count": 3, "allies": 2, "map": "wadi",
				"briefing": "Un comandante enemigo encabeza una columna blindada. Destrúyelo para romper su ataque."},
			{"title": "BIR HAKEIM", "type": "sabotage", "target": "hq", "allies": 2, "map": "box", "backdrop": {"relief": "flat", "skyline": {"n": "fort"}, "smoke": 3},
				"briefing": "Finales de mayo de 1942, batalla de Gazala. Una brigada de la Francia Libre resiste en el viejo fuerte de Bir Hakeim y amenaza el flanco de nuestro avance. Destruye su búnker de mando, la antena, los barracones y el combustible."},
			{"title": "SIDI BOU ZID", "type": "breakthrough", "allies": 2, "map": "djebel", "backdrop": {"relief": "djebel", "skyline": {"n": "village_af"}, "smoke": 3},
				"briefing": "14 de febrero de 1943, Túnez. Dos divisiones panzer salen de los pasos de Faid y Maizila contra la 1.ª División Acorazada estadounidense. Rompe sus posiciones y sigue hacia el paso de Kasserine: la salida está al norte."},
			{"title": "TEL EL AQQAQIR", "type": "defend", "time": 180, "allies": 2, "map": "box", "backdrop": {"relief": "flat", "smoke": 6},
				"briefing": "2 de noviembre de 1942, El Alamein. Los británicos han lanzado la operación Supercharge y sus carros cargan contra nuestra línea en Tel el Aqqaqir. Contenlos durante tres minutos."},
		],
	},
	Fronts.Id.KURSK: {
		Fronts.Faction.ALLIES: [
			{"title": "LA ESTEPA ARDE", "type": "assault", "count": 6, "allies": 2, "map": "defences", "overwatch": 2, "backdrop": {"skyline": {"w": "village_ru"}, "smoke": 8},
				"briefing": "Julio de 1943, Kursk. La mayor batalla de carros de la historia empieza. Detén a la vanguardia alemana."},
			{"title": "EL PUESTO DE MANDO", "type": "sabotage", "target": "hq", "allies": 1, "map": "woods", "backdrop": {"relief": "forest"},
				"briefing": "Los partisanos han localizado un puesto de mando alemán. Destruye el búnker, la antena, los barracones y el combustible."},
			{"title": "PROJOROVKA", "type": "defend", "time": 180, "allies": 3, "map": "town_center", "backdrop": {"skyline": {"n": "station_ru"}, "smoke": 9},
				"briefing": "Los Tiger avanzan hacia la aldea. Resiste tres minutos: nuestra reserva está en camino."},
			{"title": "EL ELEFANTE", "type": "boss", "count": 4, "allies": 2, "map": "rails", "backdrop": {"skyline": {"e": "station_ru"}, "smoke": 5},
				"briefing": "Un cazacarros gigante destroza nuestras columnas desde lejos. Acércate por los flancos y acaba con él."},
			{"title": "LA LIBERACIÓN", "type": "liberate", "count": 8, "allies": 2, "map": "woods", "backdrop": {"relief": "forest"},
				"briefing": "1944. Nuestra ofensiva ha llegado a un campo de prisioneros. Derriba las alambradas para abrir paso. No dispares contra los barracones: dentro hay personas."},
			{"title": "LA ESTACIÓN DE PONYRI", "type": "defend", "time": 180, "allies": 3, "map": "town_center", "backdrop": {"skyline": {"e": "station_ru"}, "smoke": 7},
				"briefing": "7 de julio de 1943, cara norte del saliente de Kursk. Los alemanes atacan con carros y cazacarros Ferdinand la estación de Ponyri, en el ferrocarril de Orel a Kursk. Resiste tres minutos."},
			{"title": "OPERACIÓN KUTÚZOV", "type": "breakthrough", "allies": 3, "map": "river", "backdrop": {"skyline": {"n": "orel"}, "smoke": 6},
				"briefing": "12 de julio de 1943. Mientras los alemanes se desgastan en Kursk, el Ejército Rojo contraataca sobre el saliente de Orel. Rompe sus defensas y alcanza la salida, al norte. Orel será liberada el 5 de agosto."},
			{"title": "OPERACIÓN RUMIÁNTSEV", "type": "assault", "count": 6, "allies": 3, "map": "villages", "backdrop": {"skyline": {"n": "kharkov"}, "smoke": 7},
				"briefing": "3 de agosto de 1943. Ofensiva soviética al sur de Kursk: el objetivo es liberar Bélgorod y Járkov. Destruye los blindados alemanes que cubren la carretera."},
		],
		Fronts.Faction.AXIS: [
			{"title": "OPERACIÓN CIUDADELA", "type": "assault", "count": 6, "allies": 2, "map": "defences", "dug_in": 3, "backdrop": {"skyline": {"n": "village_ru"}, "smoke": 6},
				"briefing": "Julio de 1943, Kursk. Rompe las primeras defensas soviéticas en la estepa."},
			{"title": "LA CENTRAL ELÉCTRICA", "type": "sabotage", "target": "power_plant", "allies": 1, "map": "steppe", "backdrop": {"skyline": {"e": "village_ru"}, "smoke": 3},
				"briefing": "Una central eléctrica abastece las fábricas y defensas soviéticas de la zona. Destruye la sala de turbinas, las chimeneas y los transformadores."},
			{"title": "LA COTA", "type": "defend", "time": 180, "allies": 3, "map": "ridge", "backdrop": {"skyline": {"w": "village_ru"}, "smoke": 4},
				"briefing": "Hemos tomado una cota. Los T-34 contraatacan en masa: resiste tres minutos."},
			{"title": "DEPÓSITOS SOVIÉTICOS", "type": "destroy", "count": 3, "allies": 1, "map": "villages",
				"briefing": "Los soviéticos han escondido combustible y munición en una aldea. Destrúyelos."},
			{"title": "EL PESADO SOVIÉTICO", "type": "boss", "count": 4, "allies": 2, "map": "steppe", "backdrop": {"skyline": {"n": "village_ru"}, "smoke": 4},
				"briefing": "Un comandante soviético en un carro pesado lidera el contraataque. Destrúyelo."},
			{"title": "ASALTO A PONYRI", "type": "assault", "count": 6, "allies": 2, "map": "town", "backdrop": {"skyline": {"e": "station_ru"}, "smoke": 7},
				"briefing": "7 de julio de 1943, cara norte del saliente de Kursk. La estación de Ponyri, en el ferrocarril de Orel a Kursk, cambia de manos una y otra vez. Destruye los carros soviéticos que la defienden."},
			{"title": "EL CRUCE DEL PSEL", "type": "breakthrough", "allies": 2, "map": "river", "backdrop": {"skyline": {"n": "village_ru"}, "smoke": 5},
				"briefing": "10 de julio de 1943, cara sur. Hay que cruzar el río Psel y ganar la cota 226,6 para seguir hacia Prójorovka. Atraviesa las defensas soviéticas y alcanza la salida, al norte."},
			{"title": "LA LÍNEA HAGEN", "type": "defend", "time": 180, "allies": 3, "map": "defences", "backdrop": {"relief": "forest", "smoke": 5},
				"briefing": "Agosto de 1943. La operación soviética Kutúzov ha hundido el saliente de Orel. Cubre el repliegue hacia la línea Hagen, al este de Briansk: resiste tres minutos."},
		],
	},
}

const PER_CAMPAIGN: int = 8


static func missions(faction: int, front_choice: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in PER_CAMPAIGN:
		list.append(_entry(front_choice, faction, i))
	return list


static func _entry(front: int, faction: int, index: int) -> Dictionary:
	var mission: Dictionary = DATA[front][faction][index].duplicate()
	mission["front"] = front
	return mission

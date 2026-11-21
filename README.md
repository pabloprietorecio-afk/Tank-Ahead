# A Tank Story

Juego de tanques en primera persona (Godot 4.7, Android). Estética retro-vectorial.

## APK
Cada push a `main` compila un APK y lo publica en **Releases**. El `versionCode` es el número de ejecución del flujo, así que cada APK se instala encima del anterior. Todos se firman con `ci/debug.keystore` (clave de depuración, no de publicación).

## Voces
Frases pregeneradas con Kokoro (fuera del juego). Las locuciones del tutorial se generan con
`python3 tools/voice_gen/tutorial_voice.py MODELO.onnx VOCES.bin` (voz de radio «em_santa») y
se guardan en `assets/voice/tutorial`. Si falta alguna, el tutorial muestra solo el texto.

## Idiomas
Diez idiomas: español (por defecto), inglés, francés, italiano, japonés, portugués de Brasil,
indonesio, hindi, alemán y ruso. Se eligen tocando la bandera vieja de arriba a la derecha del menú
principal o en OPCIONES → «IDIOMA / LANGUAGE». El texto del código está en español y es la clave de
traducción: `Loc.t("TEXTO")` lo muestra tal cual en español y lo busca en `core/i18n/<idioma>_table.gd`
en los demás (si falta, se ve en español). Para un texto nuevo basta una línea en cada tabla.

Fuentes: el japonés y el hindi llevan una fuente de respaldo (Noto Sans CJK JP en subconjunto y
Noto Sans Devanagari, ambas con licencia SIL OFL 1.1, en `assets/fonts`), que solo se activa en
esos idiomas. El cirílico y el resto de alfabetos latinos ya los trae la fuente por defecto.

Voces (`assets/voice_<idioma>`; si falta un clip se usa el español):
- Inglés, francés, italiano, japonés, portugués e hindi: Kokoro
  (`voices_en.py`, `voices_lang.py MODELO.onnx VOCES.bin CODIGO`). El francés solo tiene voz femenina.
- Indonesio, alemán y ruso: Supertonic 3 de Supertone Inc. con sherpa-onnx (`voices_supertonic.py`).
  El modelo tiene licencia BigScience Open RAIL-M: uso libre de regalías y sin derechos del autor
  sobre el audio generado, pero con restricciones de uso y la obligación de avisar de que el
  contenido está hecho por una máquina. **Ese aviso va en la ficha de Play Store: los textos, en
  los diez idiomas, están en `store/aviso_voces_ia.md` (hay que pegarlos al crear la ficha).**
  La voz indonesia de Piper (`id_ID-news_tts`) NO se usa: su conjunto de datos (INDspeech_NEWS_TTS)
  es CC BY-NC-SA, solo para uso no comercial. `voices_piper.py` (alemán y ruso con Piper, CC0) se
  conserva como alternativa, pero con el efecto de radio se entiende peor.
- Comprobación: `check_voices.py CARPETA_WHISPER CODIGO` transcribe las voces de un idioma con
  Whisper y las compara con el texto (1.00 = se oye lo escrito). Medias actuales: it 0,98; de 0,97;
  ru 0,97; pt 0,96; id 0,95; ja 0,92; hi 0,92; fr 0,90. Mide si se entiende, no si suena natural.
- Los textos de las voces de los idiomas nuevos están en `tools/voice_gen/lines/<idioma>.txt` y son
  traducciones propias, sin revisar por un nativo.

## Órdenes por voz
Debajo de los dos iconos de órdenes (todos conmigo y atacar al objetivo) hay un micrófono
(`ui/hud/voice_orders.gd`). Entiende cinco órdenes en los diez idiomas, y en todos también en
inglés: «todos conmigo», «atacar a mi objetivo», «localizar objetivo» (fija y apunta la torreta al
enemigo a la vista más cercano, hasta 300 m, aunque la ayuda de apuntado esté apagada), «lanzar
misil» (el misil guiado del botón MISIL) y «solicito bombardeo» (el bombardeo del botón AVIÓN,
sobre el objetivo fijado o donde apunta el cañón); misil y bombardeo por voz no necesitan los
prismáticos. Se reconocen por palabras clave (`LOCATE_WORDS`, `STRIKE_WORDS`, `MISSILE_WORDS`,
`FOLLOW_WORDS`, `ATTACK_WORDS`), de la más concreta a la más general.

- **Pulsar para hablar** (siempre): una pulsación abre una ventana de 6 s para dar una orden.
  Mientras dura, el sonido del juego baja 18 dB con un fundido y la radio calla
  (`AudioSetup.mic_duck`): el micrófono tiene al lado el altavoz, y el motor y los cañonazos
  tapan la voz. Al oír la orden, o al agotarse la ventana, el sonido vuelve solo.
- **Micrófono siempre abierto** (OPCIONES del menú principal o de la pausa → «Micro siempre abierto», con la nota «mejor con auriculares»,
  `GameSettings.voice_always_open`, apagado de serie): además escucha sin pulsarlo, y el icono
  queda en verde. En este modo no se toca el sonido: el reconocedor toma el propio ruido del juego
  por voz, y bajar el volumen cada vez que «oía» algo lo hacía subir y bajar sin parar. Con el
  altavoz alto puede no entender; con auriculares no hay ese problema. Mientras habla la radio
  del juego no escucha, para no tomar por órdenes sus propias voces.

El tutorial tiene una lección propia («voice», tras «todos al objetivo»): se pulsa y se da cada
orden, con un blanco lejano que se repone si cae. Sus locuciones aún no están generadas, así que
de momento es solo texto.

Usa el reconocimiento de voz del propio Android (`android.speech.SpeechRecognizer`, sin interfaz)
con un plugin propio, `android_plugins/speech_commands` (Java), que `build-apk.yml` y `build-aab.yml`
compilan en cada build con `javac` (sin Gradle) y dejan en `addons/SpeechCommands/bin`. Pide el
permiso `RECORD_AUDIO` la primera vez que se pulsa el micrófono. Si el móvil no tiene servicio de
voz (p. ej. sin servicios de Google), el micrófono no aparece, su opción sale desactivada y la
lección del tutorial se salta.

## Clima
Seis climas (`levels/weather/weather.gd`): soleado y nubes y claros (los días claros, con el sol alto),
atardecer, niebla (tormenta de arena en África), lluvia y nieve. Cada frente admite los suyos
(`Fronts.weathers`: África sin lluvia ni nieve, Normandía sin nieve) y al sortear salen más a menudo los
días claros. El jugador elige «aleatorio» o uno de los climas del frente con un desplegable: en la historia,
en el parte de la misión; en supervivencia y captura la bandera, en una pantalla previa (`_page_start`).
La elección se guarda (`GameSettings.weather`) y vale para las partidas siguientes. El tutorial es siempre
soleado.

## Trazados del campo (versión 2)
Cada misión de la historia tiene su propio mapa (`map` en `data/missions/campaign.gd`), pensado para el
sitio real; supervivencia y captura la bandera sortean uno de los abiertos de su frente. Los trazados
están en `levels/layouts.gd` y los monta `levels/arena.gd` (`_build_layout`) antes que el decorado suelto,
que se reparte por los huecos:

- **Ríos, arroyos y ramblas** (`levels/water.gd`): el río es hondo y solo se cruza por los puentes (de
  piedra en Normandía, de madera en el Este) y por los vados, donde se va más despacio; el arroyo y la
  rambla seca del desierto se vadean por cualquier sitio. El río lleva una barrera invisible en una capa
  propia, `Tank.LAYER_WATER` (solo la tocan los tanques: los disparos y la vista pasan por encima). La máquina
  lo ve en su mapa de rutas (`NavGrid`) y cruza por los pasos; nada aparece ni se coloca dentro del agua
  (`Water.deep_at`). El radar pinta el río en azul y los pasos con dos rayas. Con nieve, el agua se hiela.
- **Pueblos de verdad** (`_build_town`): calle mayor, travesía y callejas con las casas alineadas y dando
  a la calle, casas de dos plantas, plaza con pozo, iglesia (normanda u ortodoxa) o morabito, huertos y
  caminos que salen hacia los cuatro lados. En las misiones de resistir «en la aldea» o «en la estación»,
  el pueblo rodea la posición.
- **Vía de tren** con estación, depósito de agua y vagones (Ponyri, Goodwood).
- **Trincheras** (parapetos de tierra en zigzag de lado a lado), **trigales** que tapan el casco y
  **lomas grandes** en las misiones de cotas y crestas.
- Caminos, calles, orillas y agua son cintas a ras de suelo (`levels/ribbon.gd`,
  `shaders/ground_strip.gdshader`, `shaders/water.gdshader`): solo dibujo, se mojan y se nievan con el
  tiempo como el terreno.

## Tres frentes que no se confunden
Cada frente tiene su suelo, su luz, su borde, sus cosas y su horizonte (`levels/backdrop/`,
`entities/props/front_props.gd`, `data/fronts/fronts.gd`, `levels/weather/weather.gd`):

- **Normandía**: prado verde con trébol y margaritas, bocage de verdad (una cuadrícula de setos sobre
  talud con portillos, `_build_bocage`), granjas de piedra, calvarios, planeadores estrellados y
  «espárragos de Rommel». El campo lo cierra un seto. Fuera, colinas con su mosaico de parcelas y
  choperas; según la misión se ven las agujas de Caen, la acería de Colombelles, Saint-Lô en ruinas o
  el mar con la flota de invasión, los globos cautivos, las lanchas en la playa y el puerto artificial.
- **Norte de África**: arena con rizaduras, sin hierba, sol alto y cielo casi sin nubes. Peñascos,
  sangars, jaimas, camiones quemados, campos de minas cercados, acacias y matorral. No lo cierra
  nada: la arena sigue hasta las dunas (`Backdrop.open_border`), la barrera del límite no se ve y
  un aviso en pantalla dice dónde acaba el campo (`Hud._warn_border`). Fuera, mesetas con su escarpe, dunas,
  la sierra en Túnez, el fuerte de Bir Hakeim, Tobruk blanca junto a su puerto.
- **Kursk**: estepa pajiza sobre tierra negra, llana hasta el horizonte. Isbas con su pozo de cigoñal,
  molinos de viento, girasoles, almiares, abedules, línea de telégrafo junto a la vía, carros quemados.
  Fuera, franjas de cultivo, pueblos con su iglesia de cúpula, estaciones con elevador de grano, Járkov
  u Oriol a lo lejos y muchas columnas de humo (todas se tuercen con el mismo viento).

El paisaje de fuera sale de la clave `backdrop` de cada misión (`data/missions/campaign.gd`): hacia qué
lado queda el mar (`sea`, `sea_extras`), qué se ve en cada horizonte (`skyline`), el relieve y el humo.
Son maquetas fundidas en una malla por color (`Blocks`), sin colisión ni sombra. Hay más pueblos dentro
del campo donde los hubo (la costa del desembarco, Carpiquet, la llanura de Caen) y El Alamein tiene su vía.

**Playa**: en las misiones con mar, la última franja del campo es arena de playa, despejada
(`Arena.BEACH_FROM`, `beach_dir` en `shaders/grid_ground.gdshader`).

**Huellas de oruga** (`levels/track_marks.gd`, `shaders/track_marks.gdshader`): cada tanque deja el rastro
de sus dos orugas, más hondo en la arena que en la hierba; se va borrando con el tiempo y el del jugador
dura más. En el agua, los vados y los puentes no se marca.

## Entrada aérea de las misiones
Al empezar una misión de historia (`levels/intro_flight.gd`) la cámara sobrevuela el campo en espiral
desde 210 m, baja en picado y acaba en la cámara del tanque, con el título de la misión. La partida está
en pausa mientras dura (7,5 s) y se salta tocando la pantalla. Las pruebas la quitan con
`GameSession.skip_intro`; la suya es `SHOTS_ONLY=intro`.

## Sonido de ambiente y sonidos nuevos (grabaciones reales)
`levels/ambience.gd` pone un fondo propio de cada frente (pájaros y brisa en Normandía, viento en el
desierto, insectos de prado en Kursk; sin pájaros ni insectos con lluvia o nieve) y, en las misiones con
mar, el oleaje (suena desde la orilla más cercana) y alguna gaviota. Los disparos al mar o a un río
suenan a chapuzón y la cañonera de Tobruk dispara con una ráfaga real de cañón automático. Origen y
licencias en `assets/audio/CREDITS.md`. Las grabaciones se buscan y se bajan con
`.github/workflows/audio-fetch.yml` (`job=discover` busca en Wikimedia Commons; `job=fetch` baja las
elegidas de Commons y de Freesound a la rama `audio-raw`) y se montan con
`tools/sound_gen/field_sounds.py`. Commons exige un `User-Agent` con datos de contacto: sin él responde 429.

### Cañonazo, cañones lejanos y explosiones reales

- **Cañonazo de los carros** (`cannon.ogg`): un disparo de un cañón antiguo en una recreación
  histórica (kevp888, Freesound 654077, CC BY 4.0). Lo eligió de oído el autor del juego entre
  cuatro candidatos; el anterior era una mezcla de sonidos de Kenney.
- **Cañones lejanos** (`Sfx.DISTANT_GUNS`, cuatro variantes): cañonazos grabados de lejos (Andykub,
  Freesound 415293, CC0). Suenan en el duelo de artillería de más allá del horizonte
  (`SkyWar.distant_guns` → `distant_report`), con el retraso del sonido tras los fogonazos, en
  todas las partidas con cielo de guerra. Antes ahí sonaba la explosión bajada de tono.
- **Explosiones**: el menú de pausa tiene el interruptor **«Explosiones reales (prueba)»**
  (encendido de serie). Con él, `Sfx.play_at` y `Sfx.play_2d` cambian la explosión de siempre por
  la detonación de una bomba de aviación de 250 kg de la Segunda Guerra Mundial (`Sfx._pick`). Al
  moverlo suena la elegida, también en pausa (`Sfx.preview_explosion`).
- El cañonazo real de 25 libras que se probó en la 0.1.84 (grabado con una cámara) se retiró:
  sonaba mal. Los impactos contra el blindaje siguen siendo los de Kenney.
- Fuentes y licencias en `assets/audio/CREDITS.md`; el montaje, en
  `tools/sound_gen/field_sounds.py`. Prueba `sonido`.

## Batería antiaérea (supervivencia)
Cada tres oleadas (tras la 3, la 6, la 9…) y después de un respiro de 3,5 s, la vista vuela del tanque a
una batería antiaérea ligera del bando del jugador (`entities/props/aa_battery.gd`: Flak 38 de 2 cm,
Oerlikon de 20 mm o 72-K de 25 mm), montada en un sitio despejado cerca del tanque. Un cañón de tanque
no podía tirar a los aviones (el del Sherman subía a +25° y el del Panzer IV a +20°); la antiaérea sí.
Se apunta con el mismo mando que la torreta y dispara a ráfaga mientras se mantiene el gatillo
(`PlayerInputSource` desvía los mandos a `AaBattery.active`; el HUD pinta su mira de anillos). Sin
cámara lenta: los aviones de la fase van 1,6 veces más deprisa. Hay 28 s para derribar 3
(`SurvivalMode.AIR_GOAL`): al conseguirlo se repone el bombardeo, y si no pasa ni uno, además un misil.
Al acabar, la vista vuelve al tanque. El cañón se lleva con la palanca izquierda (la de mover el
tanque): se apunta con un pulgar y se dispara con el otro; arrastrar por la derecha sirve para el ajuste
fino. Desde el puesto del apuntador el cañón se ve translúcido, para que no tape el cielo.
Prueba: `SHOTS_ONLY=aereo` (`AEREO_FOTOS=1` guarda capturas).

## Costa en supervivencia y captura la bandera
Cuatro de cada diez partidas de supervivencia y de captura la bandera en Normandía y en el norte de
África se juegan junto al mar (`GameMode.coast_backdrop`): playa a un lado del campo, con la flota de
invasión o un puerto. En supervivencia el mar puede quedar a cualquier lado y nadie entra por él
(`edge_point` salta ese borde); en captura la bandera queda al este o al oeste, igual para las dos bases.
En Kursk no hay costa. `GameSession.debug_coast` la fija en las pruebas (`SHOTS_ONLY=costa`).

## Mira con objetivo fijado
Con la cámara por detrás del tanque, la mira se pinta donde la línea del cañón pasa a la distancia del
objetivo fijado (`Hud._aim_screen_point`), con una amortiguación ligera. Antes se pintaba en lo primero
que tocara esa línea sin contar los tanques (el suelo lejano o un punto a 250 m), y desde la cámara
elevada quedaba por encima del objetivo. Sin objetivo fijado cuenta también los tanques. Prueba:
`SHOTS_ONLY=mira`.

## Pantalla de carga
Al entrar en una partida (`ui/loading/`), una pantalla tapa el montaje del campo: un carro de perfil
avanza por un terreno ondulado (ruedas, eslabones y polvo animados, dibujado por código en
`LoadingArt`), con el título de la misión, «CARGANDO…» y una barra de avance. Montar el campo ocupa al
juego entero, así que `Arena._ready` lo hace por pasos y cede un cuadro entre uno y otro
(`await Loading.step(...)`); el dibujo usa el reloj de verdad y avanza aunque los cuadros lleguen a
saltos. Mientras dura, el árbol está en pausa. Sin pantalla abierta (las pruebas) la arena se monta de
una vez. `LOAD_TIMES=1` imprime lo que tarda cada paso. Prueba: `SHOTS_ONLY=carga`
(`CARGA_FOTOS=1` guarda la pantalla a tres tamaños).

## Seguir en el campo tras la victoria
El menú de misión cumplida (y el de victoria en captura la bandera) ofrece «SEGUIR EN EL CAMPO»,
solo con premium (sin premium sale marcada y lleva a la pantalla que lo explica): se
cierra y la partida sigue donde estaba. El botón de pausa lo devuelve; si destruyen el tanque del
jugador, vuelve solo. Prueba: `SHOTS_ONLY=seguir`.

## Hundir barcos: el puerto de Tobruk
Misión de tipo `sink` (campaña del Eje en África). El 20 de junio de 1942 los carros alemanes llegaron al
puerto de Tobruk y dispararon a los barcos que intentaban salir; el parte del Panzerarmee da por hundidos
una cañonera y seis transportes pequeños. En la misión, esa flotilla (`entities/props/ship.gd`) está
fondeada en la rada, fuera del campo y a tiro desde la orilla; zarpan de uno en uno hacia mar abierto y
hay que hundir cinco de los siete (`needed`). Arden, se escoran y se van a pique; la cañonera responde con
su cañón automático. Los disparos que caen al mar levantan un surtidor de espuma (`Fx.shell_water`).
Sustituye a «El cuartel general» (la campaña ya tenía otro asalto a un cuartel, Bir Hakeim) para seguir
con ocho misiones por campaña. Prueba: `SHOTS_ONLY=barcos`.

## Asaltos: oleadas y carros en posición
En las misiones de asalto (y en la escolta del comandante) el enemigo ya no gotea de uno en uno: entra en
**oleadas** de 2 a 4 carros, juntos y por el mismo lado del mapa (`StoryMode.WAVE_SIZE`, `WAVE_ALIVE`). El
objetivo anuncia la cifra real de blindados de esa dificultad. Una misión puede llevar además carros que
no salen a buscar al jugador (`AIBrain.hold_position`): `dug_in` (en pozos de tirador, con el casco
cubierto por taludes; Operación Ciudadela) u `overwatch` (carros pesados en apoyo desde lejos; La estepa
arde). Cuentan para el total.

## La guerra en el cielo
`levels/weather/sky_war.gd`: pasan formaciones más a menudo y la mitad de los cazas y aviones de asalto
lo hacen en vuelo rasante sobre el campo; más duelos de artillería en el horizonte, salvas de cohetes y
bengalas. Parte de los aviones derribados caen ahora **dentro** del campo, a la vista: solo en suelo
despejado y a más de 30 m de todo tanque, y si alguno se acerca mientras caen se desvían. No hacen daño;
dejan los restos ardiendo un rato (sin colisión). Pasa una formación cada 6-13 s, seis de cada diez
pierden un avión y dos de cada tres cazas van rasantes. Los **bombarderos sueltan su carga sobre el
terreno lejano** (`_bomb_run`): las bombas caen con su parábola siempre a más de 90 m del muro, con
fogonazo, surtidor de humo y el estampido que llega con su retraso. Y hay casi el doble de fogonazos de
artillería en el horizonte.

## Relieve: lomas
`levels/terrain.gd`. Además de las colinas y montañas (empinadas: hacen de pared, como siempre), cada
campo lleva tres o cuatro lomas suaves, de unos 12 grados de pendiente como mucho, por las que suben y
bajan todos los tanques. Cada loma es una función de altura conocida: `TankMovement` posa el tanque en
ella e inclina su chasis (`Tank.chassis`), y `TurretController` compensa esa inclinación para que el cañón
apunte igual que en el llano. La máquina las trata como suelo llano (no cuentan como obstáculo en sus
rutas); para los disparos y la línea de visión llevan un cuerpo en la capa `Terrain.LAYER`, con la que los
tanques no chocan. Nada del decorado se coloca encima de una loma.

## Tanque del jugador
El de serie de cada frente y bando (`Fronts.PLAYER_TANK`) tiene siempre la misma potencia. Con premium,
una misión ya superada se puede repetir con cualquier otro tanque del bando en ese frente (desplegable en
el parte de la misión, o «REPETIR CON OTRO TANQUE» al ganar): `Fronts.player_stats(frente, bando, id)`
cambia la potencia según lo que ese vehículo es frente al de serie (los ligeros corren más y aguantan
menos; los pesados son lentos, duros y pegan más), con su tamaño real y, en los cazacarros de casamata, el
cañón casi fijo: entonces el casco gira solo hacia donde se apunta (`PlayerInputSource`).

## Arranque: vídeo de introducción y elección de idioma

El juego abre en `ui/intro/intro.tscn` (`Intro`), no en el menú:

- **Vídeo de introducción** (`assets/video/intro.ogv`, 9,5 s): la pantalla de carga se vuelve un
  carro de verdad, gira la torreta hacia el espectador, dispara y, sobre el fogonazo, queda el
  título «A TANK / STORY» a máquina, una palabra por cañonazo. Cubre la pantalla entera (se
  recorta lo que sobre) y se salta tocando. Cómo está hecho: `assets/video/CREDITS.md`.
- **Aire de película de guerra antigua**: casi en blanco y negro tirando a sepia, con grano,
  parpadeo, rayas y motas. Va en el propio vídeo y la pantalla de idioma lo continúa (el fondo y
  el título repiten tono y grano; `shaders/old_film.gdshader` pone las rayas y el parpadeo). Las
  banderas y los colores del título se quedan en color.
- **La primera vez** (`GameSession.language_chosen`), al acabar el vídeo se queda en esa misma
  imagen: `TitleCard` pinta el título con las mismas letras y medidas (coincide al píxel), lo
  aparta a la izquierda y salen las diez banderas. Al tocar una cambia el idioma y **el título se
  viste con esa bandera** (`shaders/title_flag.gdshader`: la bandera se extiende por el bloque y
  cada letra enseña su trozo, con un perfil claro para los colores oscuros). De entrada sale el
  idioma del móvil si el juego lo habla. «EMPEZAR LA BATALLA» lleva al menú.
- **Las demás veces**, del vídeo al menú. A quien ya jugaba antes no se le pregunta el idioma.

Prueba `arranque`.

## Cazas que ametrallan y derribos a la vista

**Ametrallamiento** (`entities/air/strafe.gd`, `shaders/strafe_lane.gdshader`). Desde la tercera
misión de cada campaña, y desde la oleada 3 en supervivencia (`GameMode.strafes_active`), la mitad
de los ataques aéreos enemigos (`STRAFE_SHARE`) ya no es un bombardeo sino un caza que ametralla:

- La radio dice de dónde viene (norte, este, sur u oeste: `strafe_n`…`strafe_w`, en los diez
  idiomas) y en el suelo se marca un pasillo de 170 × 12 m que pasa por donde está el tanque. No
  va relleno (era demasiado rojo): dos rayas de trazos en los bordes y, por dentro, dos rayas que
  se cierran de fuera hacia el centro como cuenta atrás, igual que el anillo del bombardeo; en
  cada punto se juntan justo cuando llegan allí las balas. También sale en el radar.
- A los 5 s (`WARNING`; un tanque gira despacio) el caza baja, enfila el pasillo y lo barre: dos
  hileras de impactos cosen el suelo (`Fx.bullet_ground`: un pellizco de tierra, una bocanada
  pequeña de polvo, algún rebote) y bajan trazadoras finas desde las alas (`Fx.strafe_tracer`).
  La cuenta de la pantalla es hasta que las balas llegan a la altura del tanque.
- Quien siga dentro cuando le llegan pierde 30 de blindaje (`DAMAGE`), una sola vez: castiga, no
  mata. Vale igual para los aliados. Se esquiva saliendo de lado.
- No cambia la frecuencia de los ataques aéreos (`raid_interval`): alterna con el bombardeo.
- Sonidos: el motor es el del caza de ambiente y el cañón, la ráfaga real de 20 mm de la batería
  antiaérea. No se ha encontrado una grabación libre de un ametrallamiento real.
- Es igual en los tres frentes y con los dos bandos (decisión del autor: jugabilidad antes que
  fidelidad; en Normandía la aviación alemana apenas atacaba a los carros aliados).
- En francés, el texto de la voz del este es «l'este» a propósito: Kokoro lee «l'est» como el verbo.

**Derribos a la vista** (`SkyWar.VIEW_SHARE`). Caía un avión cada 16 s de media, pero casi siempre
a la espalda del jugador (en la prueba, 2 de 62 delante de la cámara). Ahora tres de cada cuatro
formaciones que van a perder un avión pasan por un punto despejado a 85-195 m por delante de lo que
mira el jugador y el avión cae allí (en la prueba, con la cámara girando, uno de cada tres). Al
caer, el motor se embala: su zumbido sube de tono hasta el suelo. Pruebas `ametralla` y `sky`.

## Aliados
En la historia salen dos aliados más de los que marca cada misión (`StoryMode.EXTRA_ALLIES`), con el
blindaje reforzado, y por cada uno que cae entra un refuerzo por el borde sur hasta agotar la reserva.
Supervivencia no tiene aliados; captura la bandera sigue siendo 4 contra 4.
Una misión marcada `"solo": true` en `data/missions/campaign.gd` se juega sin aliados ni refuerzos
propios (y sin los botones de órdenes). En prueba en la segunda misión de cada bando en el Norte de
África («Combustible enemigo» y «El aeródromo británico»), que resultaba demasiado fácil.

Con la orden «todos conmigo» los aliados marchan en formación (`entities/enemies/ai/formation.gd`): una
cuña abierta por detrás del jugador, con cada puesto a 18 m o más de los demás y del propio jugador,
ninguno por delante de él y la calle del centro libre para que pueda recular o dar media vuelta. La
formación sigue el rumbo de marcha del jugador (no gira si él gira parado), se invierte en vez de barrer
por delante cuando da media vuelta, corre a un hueco libre los puestos que caen dentro de un edificio y
reparte los puestos para que nadie se cruce. Cada aliado mantiene su puesto (`PatrolState._keep_station`):
acompasa su velocidad a la del jugador, se para cuando él se para, recula si el puesto le queda detrás,
no pasa rozando a un compañero y se aparta si el jugador viene hacia él. Lejos de su puesto lo deja todo
para volver; cerca, sigue saliendo a por el enemigo que vea.

## Ayudas para ver mejor
- Opciones «Destacar enemigos (borde amarillo)» y «Destacar objetivos (borde azul)»: edificios objetivo,
  comandante enemigo, bandera enemiga y salida de las misiones de ruptura (`shaders/outline.gdshader`; el
  borde nunca baja de un píxel y medio de grosor, para que se vea de lejos).
- Siempre: los tanques de la máquina llevan un contorno oscuro de un píxel (`shaders/contour.gdshader`) y
  todos una sombra de contacto bajo el casco (`shaders/contact_shadow.gdshader`), que los separan de un
  terreno de color parecido.
- El menú de opciones de la partida se monta a la mayor escala que cabe en la pantalla
  (`Hud._fit_pause_menu`), con interruptores y deslizadores grandes (`ui/ui_kit.gd`).

## Tutorial
Modo propio (`levels/modes/tutorial`): diecisiete lecciones (las dos últimas antes del combate final enseñan las órdenes a los aliados) en un campo de prácticas. Se ofrece la
primera vez que se abre el juego y está siempre en el menú. Lo ofrecido y lo completado se
guardan en la sección `tutorial` de `user://progress.cfg`.

## Sonidos de motor
Los motores de tanque y de avión son grabaciones reales (ver `assets/audio/CREDITS.md`).
`tools/audio_fetch` las descarga de Wikimedia Commons desde GitHub Actions (rama `audio`) y
`python3 tools/sound_gen/real_loop.py` convierte un tramo estable en un bucle sin costura.

## Anuncios (AdMob)

- Intersticial: al pasar a la siguiente partida tras ganar una misión de la historia y al acabar una de
  supervivencia. Nunca durante el combate ni tras perder en la historia. Política: ninguno en los dos
  primeros finales de la sesión, luego como mucho uno cada dos finales y siempre con 3 minutos de margen.
- Recompensado: en la pantalla premium, «Ver un anuncio y jugar esta misión» abre esa misión de pago una
  vez (hasta superarla). Solo se ofrece para la siguiente misión por jugar.
- Premium quita todos los anuncios. Sin consentimiento (UMP) tampoco se piden; en las regiones que lo exigen
  hay un botón «Privacidad de los anuncios» en Opciones.
- El AAB de Google Play lleva los anuncios **reales** (`IS_REAL = true` y los dos ID de bloque en
  `core/ads_config.gd`; `is_real=true` y el ID de aplicación en `addons/AdmobPlugin/android_export.cfg`; la
  verificación comprueba que coinciden). Los APK de pruebas usan siempre los de prueba de Google.
- Si una carga falla (sin red, o «sin relleno» mientras AdMob no tiene anuncios para la app) se reintenta
  al minuto, a los dos, a los tres... y después cada cinco, sin dejar de intentarlo.
- Diagnóstico: cinco toques seguidos en el título «A TANK STORY» del menú enseñan en una esquina el estado
  de los anuncios (en marcha o no, consentimiento, si hay alguno cargado, cuándo toca el próximo y el
  último error de Google). Funciona también en la versión de Google Play; en los APK de pruebas está
  siempre a la vista.
- Plugin oficial `godot-sdk-integrations/godot-admob` v7.0 (paquete Android ya compilado, ver
  `addons/AdmobPlugin/ORIGEN.txt`).

## Nivel premium

En el modo historia, las tres primeras misiones de cada frente son gratuitas y el resto exige premium
(`core/premium.gd`). Premium también quita los anuncios. Supervivencia, captura la bandera,
tutorial y fichas siguen libres. La compra con Google Play Billing aún no está conectada: en el APK de
pruebas hay un botón «[PRUEBAS] Activar premium» en la pantalla premium.

## Publicar en Google Play (AAB firmado)
Workflow `build-aab.yml` (Actions > *Build AAB (Google Play)* > *Run workflow*, o una etiqueta `aab-N`).
1. Una sola vez, crear en GitHub (*Settings > Secrets and variables > Actions*) tres secretos:
   `RELEASE_KEYSTORE_BASE64` (la clave de subida en base64), `RELEASE_KEYSTORE_PASSWORD` y `RELEASE_KEY_ALIAS`.
   La misma contraseña protege el almacén y la clave. Sin ellos el workflow compila con una clave
   desechable («modo prueba») solo para validar; ese AAB **no** se publica y **no** sirve para Google Play.
2. El AAB firmado queda en la release privada **aab-latest** (solo se conserva el último). El `versionCode`
   es el número de ejecución de este workflow y `versionName` es `0.2.N` (los APK de pruebas son `0.1.x`).
3. Cada ejecución comprueba el AAB (`tools/aab/inspect_aab.sh`): `targetSdk` ≥ 36, no depurable, permisos
   previstos, librerías nativas alineadas a 16 KB y firma. El informe queda en la rama `aab-report`.
4. Subir el AAB a Play Console. Se usa **Play App Signing**: la clave de este repositorio es solo la de
   *subida* (si se pierde, Google permite restablecerla). El nombre de paquete `com.pabloprieto.tankahead`
   es **permanente** en cuanto se sube el primer AAB.
5. Los textos de la ficha (incluido el aviso de voces IA, obligatorio por la licencia de Supertonic) están en `store/`.

## Comprobación
Cada push a una rama que no sea `main` ejecuta `verify.yml`: prueba las misiones nuevas, la navegación de los tanques aliados, su formación al seguir al jugador (recta, giros, media vuelta, marcha atrás, en campo abierto y entre casas) y el tutorial completo
(un jugador automático hace la acción correcta en cada lección) sin gráficos, y guarda capturas y registros en la rama `verify-shots`.
También comprueba que los tanques suben y bajan las lomas (y siguen sin poder subir a las colinas), que el menú de opciones cabe en
pantalla en los diez idiomas, las fichas de los tanques que puede llevar el jugador, los refuerzos aliados y los bordes de ayuda.
Con los trazados: arranca las 48 misiones y comprueba que todo sigue siendo accesible y que nada queda dentro de un río (`mapas`), que los
aliados cruzan el río por los pasos y que un tanque no lo cruza por donde no hay paso (`rios`), y que ningún avión derribado cae sobre un tanque.
`SHOTS_ONLY=vista_mapas` (a mano) guarda vistas de los mapas nuevos y `SHOTS_ONLY=vista_frentes` las del paisaje de cada frente
(`FRENTE_SOLO`, `FRENTE_LADOS`, `FRENTE_ALTO`, `FRENTE_HUELLAS`). `intro` comprueba la entrada aérea y `barcos` la misión de Tobruk; el
cielo (`sky`) comprueba además que las bombas de los aviones de ambiente caen siempre fuera del campo.
Y, ya con gráficos, que los bordes de ayuda y el contorno de los tanques no cambian las sombras del campo: son el modelo hinchado y en la
pasada de sombras se reducen a un punto (`IN_SHADOW_PASS`), porque ahí el grosor «en píxeles» sale de metros.

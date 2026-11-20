# Créditos de sonido

- Cañón, explosiones e impactos: mezclas propias a partir de sonidos de **Kenney** (www.kenney.nl),
  packs *Sci-Fi Sounds*, *Impact Sounds* y *Desert Shooter Pack*, con licencia
  **CC0 1.0 (dominio público)**. Obtenidos de la copia de github.com/series-ai/jam-ready-assets.
- Explosión real, en prueba (`explosion_real.ogg`): «FliegerbombensprengungMuenchen2012» de
  Simon Aschenbrenner (Wikimedia Commons, **CC BY 3.0**): la detonación controlada de una bomba de
  aviación de 250 kg de la Segunda Guerra Mundial en Schwabing (Múnich) el 28 de agosto de 2012,
  grabada a unos 300 m. Recorte de 2,8 s desde la detonación y nivel igualado; la grabación satura
  en el primer instante.
  Suena en lugar de la explosión de Kenney mientras esté encendido el ajuste «Explosiones reales
  (prueba)» del menú de pausa. Se eligió por su ficha y por el análisis de la onda y del
  espectrograma, sin escucharla.
- Lluvia y trueno: sintetizados por código para este proyecto.
- Motores de tanque (grabaciones reales, Wikimedia Commons, **CC BY-SA 3.0**, Nederlands Instituut
  voor Beeld en Geluid). Los bucles del juego son adaptaciones (recorte, fundido en bucle y
  ecualización) y se distribuyen con la misma licencia CC BY-SA 3.0:
  - `engine_idle.wav`: «Sherman tank, rijden, stationair en stoppen» (ralentí de un Sherman).
  - `engine_tank.wav`: «Sherman tank, rijden en manoeuvreren» (Sherman pasando de cerca).
  - `engine_drive.wav` y `engine_heavy.wav`: «Centurion tank, starten, rijden en stoppen»
    (grabado a bordo de un Centurion, motor Rolls-Royce Meteor, el mismo del Cromwell).
- Motores de avión (grabaciones reales, Wikimedia Commons), adaptados igual y con la misma licencia:
  - `plane_fighter.wav`: «RR Merlin 66-266» de Peter Ellis, **CC BY-SA 3.0** (motor Rolls-Royce
    Merlin de un Spitfire Mk VIII/XVI, Temora Aviation Museum).
  - `plane_bomber.wav`: «McDonnell Douglas DC-3 Dakota, vliegen», Beeld en Geluid, **CC BY-SA 3.0**
    (bimotor de la época en vuelo).
- Música («menu_theme», «battle_theme»): composición original para este juego, interpretada con
  la fuente de sonido FluidR3_GM (licencia MIT) mediante FluidSynth.
- Estampido de la antiaérea (`flak.ogg`): un disparo de «Sexton artillery firing» de
  LouiseBrown1981 (Wikimedia Commons, **CC BY-SA 3.0**): cañón autopropulsado Sexton de 25 libras,
  de la Segunda Guerra Mundial, disparando en Fort Nelson. Recortado y ecualizado; misma licencia.
- Cañón automático antiaéreo (`aa_burst.ogg`, `aa_fire.wav`, `aa_tail.ogg`): una ráfaga de «Flabshoot»
  de Kobel (Wikimedia Commons, **CC BY-SA 3.0**), vídeo de un ejercicio de tiro de la antiaérea suiza
  (la ficha no dice el modelo del cañón; cadencia medida, unos 17 disparos por segundo). Recorte, bucle
  del tramo central y cola; misma licencia. La grabación satura en los disparos.
- Chapuzón de un proyectil en el agua (`splash.ogg`): «Rock Splash» de Fission9 (Freesound 583348,
  **CC0**): una piedra de 3 a 5 kg cayendo a un arroyo.
- Ambiente de cada frente (bucles hechos con `tools/sound_gen/field_sounds.py`, que elige el tramo más
  parejo de cada grabación):
  - `amb_normandy.wav`: «Gentle breeze and birds singing» de ezwa (pdsounds, Wikimedia Commons,
    **dominio público**): brisa con una curruca capirotada y un pinzón.
  - `amb_africa.wav`: «Desert binaural Wind» de Benbojangles (Freesound 457159, **CC0**): viento que
    arrastra arena en el desierto del interior de Fuerteventura.
  - `amb_kursk.wav`: «Summer meadow - Houghton Lodge» de richwise (Freesound 815552, **CC0**): insectos
    en la hierba alta y seca de un prado en verano, con algún pájaro y brisa.
  - `amb_sea.wav`: «Waves On The Beach (Sand Wash)» de ralph.whitehead (Freesound 470648, **CC0**):
    oleaje en una playa de arena del Atlántico (Falmouth).
- Gaviotas: `gull_herring.ogg`, de «XC707075 - European Herring Gull - Larus argentatus» (Sonothèque
  ADVL, Wikimedia Commons, **CC0**); `gull_med.ogg`, de «Yellow-legged Gull - Larus michahellis
  michahellis» de Cedric Mroczko (Wikimedia Commons, **CC BY-SA 4.0**; recorte con la misma licencia).
- De Freesound se usa la escucha previa de alta calidad (MP3), que es pública. Estas grabaciones se
  eligieron por su ficha, su licencia y la forma de la onda, **sin oírlas**.
- Voz de radio «air_phase» (aviso de ataque aéreo): Kokoro TTS, voz «em_santa», con efecto de radio.
- Radio del menú, bando alemán, partes militares (`radio_de_0` a `radio_de_3`): textos originales
  locutados con la voz «Thorsten» (Thorsten-Voice, dataset CC0) y Piper TTS. No son grabaciones de época.
- Radio del menú, grabaciones de época (extractos recortados y filtrados como una emisora de onda
  media). Descargadas de Wikimedia Commons, donde figuran como **dominio público**:
  - `radio_al_0`, `radio_al_1`: Winston Churchill, «Be Ye Men of Valour», BBC, 19-5-1940.
  - `radio_al_2`, `radio_al_3`: Dwight D. Eisenhower, orden del día del Día D, junio de 1944 (US Army).
  - `radio_al_4`: Franklin D. Roosevelt ante el Congreso, 8-12-1941.
  - `radio_al_5`: Neville Chamberlain, declaración de guerra, 3-9-1939.
  - `radio_al_6`: Guy Byam (BBC), salto en paracaídas del Día D, junio de 1944.
  - `radio_al_7`: BBC Home Service, cruce de la frontera holandesa, 4-9-1944.
  - `radio_al_8`: Yuri Levitán, anuncio del ataque alemán a la URSS (regrabación de los años 50).
  - `radio_de_4`: Adolf Hitler, fragmento sobre los tratados internacionales (archivo «Hit43.ogg»).
  - `radio_de_5` a `radio_de_7`: Adolf Hitler, discurso radiado del 30-1-1945. Extractos elegidos
    con la transcripción delante: llamamiento a resistir y referencias a la guerra, sin los
    pasajes de odio. Se usan como documento histórico de ambiente, igual que en un documental.
- Voces en español de tripulación y radio: Kokoro TTS (Apache 2.0), voces «em_alex» y «em_santa»,
  con efecto de radio añadido.
- Voces en inglés de tripulación, radio y tutorial (`assets/voice_en`): Kokoro TTS (Apache 2.0), voces «am_michael» y «bm_george», con el mismo efecto de radio.

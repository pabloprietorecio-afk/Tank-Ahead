# Vídeo de introducción

`intro.ogv` (1280 × 720, 24 imágenes por segundo, Theora + Vorbis) es el arranque del juego:

1. **La pantalla de carga que se vuelve un carro de verdad, gira la torreta y dispara.** Generado
   por el autor del juego con **PixVerse** (imagen a vídeo) a partir de un fotograma de la propia
   pantalla de carga (`tools/film/loading_film.tscn`). El clip de partida era una grabación de
   pantalla de poca resolución (zona útil de 480 × 254), ampliada; conviene rehacerlo con el
   original descargado de PixVerse. **Pendiente de confirmar que el plan de PixVerse con el que se
   generó permite el uso comercial.**
2. **El fogonazo completo y el título «A TANK / STORY», una palabra por cañonazo.** Añadido con
   `tools/film/make_intro.py`: tipografía Special Elite (ver `assets/fonts/CREDITS.md`) y los
   sonidos del propio juego (`cannon.ogg`, `distant_gun_1.ogg`, `explosion_real.ogg`; sus créditos,
   en `assets/audio/CREDITS.md`).

3. **El aire de noticiario de guerra** (casi blanco y negro tirando a sepia, grano, parpadeo,
   rayas, motas y baile de la ventanilla), también de `make_intro.py` (`INTRO_RETRO`, 0 lo quita).
   La pantalla de idioma lo continúa con `shaders/intro_backdrop.gdshader` (tono y grano),
   `shaders/title_flag.gdshader` (grano) y `shaders/old_film.gdshader` (rayas, motas, parpadeo).

Cómo rehacerlo: `INTRO_HOLD=40 INTRO_FADE=0 python3 tools/film/make_intro.py CLIP.mp4
SpecialElite-Regular.ttf assets/audio salida.mp4` y después
`ffmpeg -i salida.mp4 -c:v libtheora -q:v 5 -c:a libvorbis -q:a 5 assets/video/intro.ogv`
(calidad 5: con el grano, más calidad dobla el tamaño sin que se note).
El vídeo debe acabar con el título quieto y sin fundido: la pantalla de idioma empieza con esa
misma imagen (`ui/intro/title_card.gd` repite sus medidas).

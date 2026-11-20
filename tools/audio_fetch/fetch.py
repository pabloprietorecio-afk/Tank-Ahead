#!/usr/bin/env python3
"""Descarga de Wikimedia Commons las grabaciones elegidas, las pasa a OGG mono y transcribe las
de voz (para elegir los extractos sabiendo qué se dice). Deja todo en audio_raw/."""
import os, subprocess, sys, time, urllib.parse, urllib.request

UA = {"User-Agent": "ATankStoryAudioFetch/1.1 (https://github.com/pabloprietorecio-afk/Tank-Ahead; pabloprietorecio-afk@users.noreply.github.com) python-urllib"}
# id: (archivo en Commons, idioma si es voz, [inicio s, duración s] opcional)
FILES = {
    "churchill_valour": ("Winston Churchill - Be Ye Men of Valour.ogg", "en", None),
    "eisenhower_dday": ("Gen. Dwight D. Eisenhower s D-Day order of the day.mp3", "en", None),
    "roosevelt_infamy": ("Roosevelt Infamy.ogg", "en", None),
    "chamberlain_war": ("Chamberlain-war-declaration.ogg", "en", None),
    "bbc_byam_dday": ("Guy Byam - D-Day parachute drop.flac", "en", None),
    "bbc_border_1944": ("4-sep-1944 BBC army crossing Dutch border.ogg", "en", None),
    "levitan_attack": ("Levitan USSR attacked.ogg", "ru", None),
    "hitler_1945": ("Adolf Hitler’s last speech.ogg", "de", None),
    "hitler_1943": ("Hit43.ogg", "de", None),
    "hitler_x": ("Hit.ogg", "de", None),
    "hitler_1935": ("Adolf Hitler Speech in 1935.ogg", "de", None),
    "tank_centurion_ride": ("Centurion tank, starten, rijden en stoppen - SoundCloud - Beeld en Geluid.ogg", None, None),
    "tank_centurion_idle": ("Centurion tank, stationair, pompen en afschakelen - SoundCloud - Beeld en Geluid.ogg", None, None),
    "tank_sherman_idle": ("Sherman tank, rijden, stationair en stoppen - SoundCloud - Beeld en Geluid.ogg", None, None),
    "tank_sherman_drive": ("Sherman tank, rijden en manoeuvreren - SoundCloud - Beeld en Geluid.ogg", None, None),
    "tank_sherman_fast": ("Sherman tank, met grote snelheid rijden - SoundCloud - Beeld en Geluid.ogg", None, None),
    "plane_spitfire": ("Spitfire fly past at RAF Halton.ogg", None, None),
    "plane_merlin": ("RR Merlin 66-266.ogg", None, None),
    "plane_dc3": ("McDonnell Douglas DC-3 Dakota, vliegen - SoundCloud - Beeld en Geluid.ogg", None, [0, 240]),
    "plane_steady": ("Propeller-plane-flying-steady-01.wav", None, None),
    "plane_trimotor": ("EAA Ford TriMotor NC8407.ogg", None, None),
    "gun_sexton": ("Sexton artillery firing.oga", None, None),
    # Cañón automático (Bofors de 40 mm), ambiente de cada frente, mar y gaviotas.
    "gun_bofors": ("IJssellinie Olst Bofors 44 mm demo.ogv", None, None),
    "gun_flab": ("Flabshoot.webm", None, None),
    "amb_breeze_birds": ("Gentle breeze and birds singing.ogg", None, None),
    "amb_skylark": ("Alauda arvensis - Eurasian Skylark XC484052.mp3", None, None),
    "amb_crickets": ("Atmo – Grillen mit Vögel.mp3", None, None),
    "amb_bushcricket": ("BioAcoustica 561 5 Metrioptera roeselli fedt 757r1.flac", None, [0, 90]),
    "amb_sea": ("Sea waves.wav", None, None),
    "amb_pebble_beach": ("On a pebble beach.ogg", None, None),
    "gull_med": ("Yellow-legged Gull - Larus michahellis michahellis.ogg", None, None),
    "gull_herring": ("XC707075 - European Herring Gull - Larus argentatus.mp3", None, None),
    # Candidatas para el cañonazo y las explosiones.
    "gun_25pdr": ("25 pounder firing a blank.ogv", None, None),
    "gun_salute": ("01 Salute Cannon Reveille.ogg", None, None),
    "boom_single": ("Explosion-LS100155.ogg", None, None),
    "boom_several": ("Explosions-LS100155.ogg", None, None),
    "boom_several_2": ("Explosions-LS100150.ogg", None, None),
    "boom_ww2_bomb": ("FliegerbombensprengungMuenchen2012.ogv", None, None),
    "boom_vaires": ("Demolition of coal power plant Vaires D20101211 2 of 2.ogv", None, None),
    "boom_bridge": ("Brückensprengung.ogv", None, None),
    "gun_abrams_au": ("Australian M1 Abrams tank conducting target practice in May 2017.webm", None, None),
    "gun_abrams_pl": ("B-Roll- Tank warfare demonstration features U S Army in Poland (970166).webm", None, None),
    "gun_m60": ("Brazilian M60A3 TTS Live fire.webm", None, None),
    "gun_tank_lfx": ("Soldiers Complete Tank Live Fire Training NiulEmTbG 0.webm", None, None),
}
# Freesound (solo sonidos con licencia Creative Commons 0): id: página del sonido. Se baja la
# escucha previa de alta calidad, que es pública (la descarga del original pide cuenta).
FREESOUND = {
    # id: (página, [inicio s, duración s] opcional)
    "splash_rock": ("https://freesound.org/s/583348/", None),
    "amb_desert_wind": ("https://freesound.org/s/457159/", [20, 150]),
    "amb_desert_wind_2": ("https://freesound.org/s/146914/", None),
    "amb_sea_atlantic": ("https://freesound.org/s/470648/", [30, 120]),
    "amb_sea_gentle": ("https://freesound.org/s/376795/", None),
    "amb_meadow_summer": ("https://freesound.org/s/815552/", None),
    "amb_meadow_france": ("https://freesound.org/s/539174/", [0, 150]),
    "amb_countryside_dawn": ("https://freesound.org/s/275755/", [10, 150]),
    "gulls_a": ("https://freesound.org/s/377107/", None),
    "gulls_b": ("https://freesound.org/s/207130/", None),
    # Cañonazos candidatos (para que el autor del juego los oiga antes de usarlos).
    "gun_airshow": ("https://freesound.org/s/415293/", None),
    "gun_salute_field": ("https://freesound.org/s/43783/", None),
    "gun_reenactment": ("https://freesound.org/s/654077/", None),
    "gun_canon_aif": ("https://freesound.org/s/14615/", None),
}

os.makedirs("audio_raw", exist_ok=True)
log = open("audio_raw/README.txt", "a")
import re
BROWSER = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"}
for key, (page, window) in FREESOUND.items():
    if os.path.exists(f"audio_raw/{key}.ogg"):
        continue
    try:
        opened = urllib.request.urlopen(urllib.request.Request(page, headers=BROWSER), timeout=60)
        response_url = opened.geturl()
        html = opened.read().decode("utf-8", "replace")
        found = re.search(r"https://cdn\.freesound\.org/previews/[0-9]+/[0-9_]+-hq\.mp3", html)
        # Solo licencias que dejan usarlo en un juego con anuncios: CC0 o Atribución (no las NC).
        link = re.search(r"creativecommons\.org/(publicdomain/zero|licenses/[a-z\-]+)/([0-9.]+)", html)
        kind = link.group(1).split("/")[-1] if link else ""
        licence = {"zero": "CC0", "by": "CC BY " + (link.group(2) if link else "")}.get(kind, "")
        if not found or not licence:
            raise RuntimeError("sin escucha previa" if not found else f"licencia no admitida ({kind or 'no se ve'})")
        source = "source_" + key
        with urllib.request.urlopen(urllib.request.Request(found.group(0), headers=BROWSER), timeout=180) as response, open(source, "wb") as out:
            out.write(response.read())
        out = f"audio_raw/{key}.ogg"
        cut = ["-ss", str(window[0]), "-t", str(window[1])] if window else []
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", source, *cut, "-vn", "-ac", "1", "-ar", "32000", "-c:a", "libvorbis", "-q:a", "6", out], check=False)
        duration = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", out], capture_output=True, text=True).stdout.strip()
        author = re.search(r"freesound\.org/people/([^/]+)/sounds", response_url)
        print("OK", key, duration, flush=True)
        log.write(f"{key}: {duration} s | Freesound, {licence}, autor {author.group(1) if author else '?'} | {response_url}\n")
    except Exception as error:
        print("ERROR", key, error, flush=True)
        log.write(f"{key}: NO DESCARGADO ({page}: {error})\n")
    time.sleep(5)
model = None
for key, (name, lang, window) in sorted(FILES.items(), key=lambda item: item[1][1] is not None):
    if os.path.exists(f"audio_raw/{key}.ogg"):
        continue
    url = "https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(name)
    source = "source_" + key
    ok = False
    for attempt in range(3):
        time.sleep(8 + attempt * 30)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as response, open(source, "wb") as out:
                out.write(response.read())
            ok = True
            break
        except Exception as error:
            print("ERROR", key, error, flush=True)
    if not ok:
        log.write(f"{key}: NO DESCARGADO ({name})\n")
        continue
    out = f"audio_raw/{key}.ogg"
    cut = ["-ss", str(window[0]), "-t", str(window[1])] if window else []
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", source, *cut, "-vn", "-ac", "1", "-ar", "32000", "-c:a", "libvorbis", "-q:a", "5", out], check=False)
    duration = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", out], capture_output=True, text=True).stdout.strip()
    print("OK", key, duration, flush=True)
    # Ficha del archivo (qué es, de quién, licencia y categorías), para saber qué se ha bajado.
    card = ""
    try:
        import json
        query = urllib.parse.urlencode({"action": "query", "format": "json", "titles": "File:" + name, "prop": "imageinfo|categories", "iiprop": "extmetadata", "cllimit": "30"})
        data = json.load(urllib.request.urlopen(urllib.request.Request("https://commons.wikimedia.org/w/api.php?" + query, headers=UA), timeout=40))
        page = list(data["query"]["pages"].values())[0]
        meta = (page.get("imageinfo") or [{}])[0].get("extmetadata", {})
        clean = lambda key_name: re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", meta.get(key_name, {}).get("value", ""))).strip()
        cats = ", ".join(c["title"].replace("Category:", "") for c in page.get("categories", []) if "license" not in c["title"].lower() and "CC-" not in c["title"])
        card = f" | {clean('LicenseShortName')} | {clean('Artist')[:60]} | {clean('ImageDescription')[:300]} | categorías: {cats[:300]}"
    except Exception as error:
        card = f" | ficha no leída: {error}"
    log.write(f"{key}: {duration} s | {name}{card}\n")
    if lang:
        try:
            if model is None:
                from faster_whisper import WhisperModel
                model = WhisperModel("small", device="cpu", compute_type="int8")
            segments, _info = model.transcribe(out, language=lang, vad_filter=True)
            with open(f"audio_raw/{key}.txt", "w") as text:
                for segment in segments:
                    text.write("%7.1f %7.1f %s\n" % (segment.start, segment.end, segment.text.strip()))
        except Exception as error:
            print("ERROR transcripción", key, error, flush=True)
    os.remove(source)
log.close()

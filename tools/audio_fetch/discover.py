#!/usr/bin/env python3
"""Busca en Wikimedia Commons grabaciones candidatas y lista licencia, tamaño y descripción."""
import json, re, sys, urllib.parse, urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "ATankStory-audio-fetch/1.0 (github.com/pabloprietorecio-afk/Tank-Ahead)"}
QUERIES = sys.argv[1:] or [
    "Churchill speech", "Hitler Rede", "Hitler speech", "Wehrmachtbericht", "Sondermeldung", "Reichsrundfunk",
    "Großdeutscher Rundfunk", "Eisenhower D-Day", "Roosevelt 1941", "Roosevelt fireside 1942", "BBC 1944", "Montgomery",
    "Levitan", "Stalin 1941", "radio broadcast 1944", "radio broadcast 1943", "Rundfunk 1939", "Rundfunk 1941", "Rundfunk 1944",
    "tank engine", "Panzer", "tank sound", "T-34", "Sherman tank", "diesel engine", "tracked vehicle", "Kettenfahrzeug", "Motor Leerlauf",
    "bulldozer", "tractor engine", "engine idle", "engine start",
    "Spitfire", "Merlin engine", "Messerschmitt", "Mustang P-51", "propeller aircraft", "B-17", "radial engine", "Stuka",
    "Ju 52", "flyby", "flypast", "warbird", "aircraft engine", "Douglas DC-3", "Lancaster bomber", "Flugzeug Überflug",
    "anti-aircraft", "Flak", "artillery fire", "cannon fire", "explosion", "air raid siren",
]


def clean(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html or "")).strip()


for query in QUERIES:
    params = {
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": "6",
        "gsrsearch": "filetype:audio " + query, "gsrlimit": "25", "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata",
    }
    try:
        request = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers=UA)
        data = json.load(urllib.request.urlopen(request, timeout=40))
    except Exception as error:
        print(f"## {query}: ERROR {error}")
        continue
    pages = sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0))
    print(f"## {query}: {len(pages)}")
    for page in pages:
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata", {})
        get = lambda key: clean(meta.get(key, {}).get("value", ""))
        print("%s | %s | %d KB | %s | %s | %s | %s" % (
            page["title"], info.get("mime", "?"), info.get("size", 0) // 1024, get("LicenseShortName"),
            get("DateTimeOriginal")[:20], get("Artist")[:40], get("ImageDescription")[:160]))

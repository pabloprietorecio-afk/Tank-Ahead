#!/usr/bin/env python3
"""Monta los sonidos de ambiente y los de la antiaérea y el agua a partir de grabaciones reales
(no va en el APK). Las grabaciones las baja tools/audio_fetch/fetch.py a la rama audio-raw.

Uso: field_sounds.py CARPETA_AUDIO_RAW CARPETA_ASSETS_AUDIO
Bucles: se elige el tramo más parejo de la grabación (el que menos cambia de nivel), se funde su
cola con su principio y se deja a un nivel medio fijo. Sueltos: recorte, fundido y pico fijo.
"""
import hashlib, os, subprocess, sys, wave
import numpy as np

RAW, OUT = sys.argv[1], sys.argv[2]
SR = 22050


def load(name, start=0.0, length=None, extra="highpass=f=60"):
    cut = ["-ss", str(start)] + (["-t", str(length)] if length else [])
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", *cut, "-i", os.path.join(RAW, name), "-ac", "1", "-ar", str(SR),
                          "-af", extra, "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def level(x):
    return 20 * np.log10(max(np.sqrt((x ** 2).mean()), 1e-9))


def steadiest(x, length, step=1.0):
    """Inicio (s) de la ventana de `length` s cuyo nivel cambia menos de medio segundo en medio segundo."""
    n = int(SR * 0.5)
    frames = np.sqrt((x[: len(x) // n * n].reshape(-1, n) ** 2).mean(axis=1) + 1e-12)
    frames = 20 * np.log10(frames)
    size, best, at = int(length / 0.5), None, 0.0
    for i in range(0, len(frames) - size, int(step / 0.5)):
        spread = frames[i:i + size].std()
        if best is None or spread < best:
            best, at = spread, i * 0.5
    return at, best


def write_wav(name, x, loop):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes())
    res = "res://assets/audio/" + name
    digest = hashlib.md5(res.encode()).hexdigest()
    imp, uid = path + ".import", ""
    if os.path.exists(imp):
        for line in open(imp):
            if line.startswith("uid="):
                uid = line
    with open(imp, "w") as fh:
        fh.write(f'[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n{uid}path="res://.godot/imported/{name}-{digest}.sample"\n\n[deps]\n\n'
                 f'source_file="{res}"\ndest_files=["res://.godot/imported/{name}-{digest}.sample"]\n\n[params]\n\n'
                 "force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\n"
                 f"edit/normalize=false\nedit/loop_mode={2 if loop else 0}\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=2\n")


def loop(out, source, length, fade, target_db, start=None, extra="highpass=f=60"):
    x = load(source, extra=extra)
    spread = 0.0
    if start is None:
        start, spread = steadiest(x, length + fade)
    a, n, f = int(start * SR), int(length * SR), int(fade * SR)
    x = x[a: a + n + f]
    t = np.linspace(0.0, np.pi / 2.0, f)
    body = x[:n].copy()
    body[:f] = x[:f] * np.sin(t) + x[n:n + f] * np.cos(t)
    body *= 10 ** ((target_db - level(body)) / 20.0)
    # Los picos sueltos (un trino muy cerca del micro) se redondean en vez de recortarse en seco.
    body = np.tanh(body * 1.2) / 1.2
    write_wav(out, body, True)
    print(f"{out}: bucle de {length:.0f} s desde {start:.1f} s de {source} (variación {spread:.1f} dB), nivel {level(body):.1f} dB, pico {20*np.log10(np.abs(body).max()):.1f} dB")


def shot(out, source, start, length, fade_out, peak_db, fade_in=0.004, extra="highpass=f=40", drive=0.0):
    """`drive` (dB): empuja la señal contra un tope redondeado, para que un estampido corto suene
    tan fuerte como los demás sonidos del juego sin recortarse en seco."""
    x = load(source, start, length, extra)
    x[: int(fade_in * SR)] *= np.linspace(0.0, 1.0, int(fade_in * SR))
    f = int(fade_out * SR)
    x[-f:] *= np.linspace(1.0, 0.0, f) ** 2
    if drive > 0.0:
        x = np.tanh(x / max(np.abs(x).max(), 1e-9) * 10 ** (drive / 20.0))
    x *= 10 ** (peak_db / 20.0) / max(np.abs(x).max(), 1e-9)
    tmp = os.path.join(OUT, out + ".tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, out)], check=True)
    os.remove(tmp)
    print(f"{out}: {length:.2f} s desde {start:.2f} s de {source}, nivel {level(x):.1f} dB")


def onset(source, around, span=0.5):
    """Instante (s) en que salta el estampido, buscado `span` s a cada lado de `around`."""
    x = load(source, around - span, 2.0 * span, "highpass=f=40")
    n = int(SR * 0.002)
    frames = np.sqrt((x[: len(x) // n * n].reshape(-1, n) ** 2).mean(axis=1) + 1e-12)
    first = int(np.argmax(frames > 0.25 * frames.max()))
    return around - span + first * 0.002 - 0.004


def loudest(source, length):
    """Inicio (s) de la ventana de `length` s con más energía (la llamada más clara)."""
    x = load(source)
    n = int(SR * 0.1)
    frames = (x[: len(x) // n * n].reshape(-1, n) ** 2).mean(axis=1)
    size = int(length / 0.1)
    sums = np.convolve(frames, np.ones(size), "valid")
    return max(float(np.argmax(sums)) * 0.1 - 0.15, 0.0)


# Fondo de cada frente.
loop("amb_normandy.wav", "amb_breeze_birds.ogg", 27.0, 2.5, -27.0, start=1.0)
loop("amb_africa.wav", "amb_desert_wind.ogg", 36.0, 3.0, -25.0)
loop("amb_kursk.wav", "amb_meadow_summer.ogg", 36.0, 3.0, -27.0)
loop("amb_sea.wav", "amb_sea_atlantic.ogg", 30.0, 3.0, -25.0)
# Gaviotas: la llamada más clara de cada grabación.
shot("gull_herring.ogg", "gull_herring.ogg", loudest("gull_herring.ogg", 4.5), 4.8, 0.6, -3.0, 0.15)
shot("gull_med.ogg", "gull_med.ogg", loudest("gull_med.ogg", 4.5), 4.8, 0.6, -3.0, 0.15)
# Chapuzón de un proyectil en el agua.
shot("splash.ogg", "splash_rock.ogg", 0.0, 3.2, 0.5, -1.0)
# Antiaérea: la primera ráfaga de la grabación (8,9 a 10,2 s). Entera para un disparo suelto, su
# tramo central en bucle para el fuego sostenido y su final para la cola al soltar el gatillo.
shot("aa_burst.ogg", "gun_flab.ogg", 8.9, 1.55, 0.25, -1.0, 0.01)
shot("aa_tail.ogg", "gun_flab.ogg", 10.12, 0.5, 0.42, -3.0, 0.01)
x = load("gun_flab.ogg", 9.2, 0.8 + 0.1, "highpass=f=40")
n, f = int(0.8 * SR), int(0.1 * SR)
t = np.linspace(0.0, np.pi / 2.0, f)
body = x[:n].copy()
body[:f] = x[:f] * np.sin(t) + x[n:n + f] * np.cos(t)
body *= 10 ** (-1.0 / 20.0) / np.abs(body).max()
write_wav("aa_fire.wav", body, True)
print(f"aa_fire.wav: bucle de 0,8 s, nivel {level(body):.1f} dB")

# Explosión: la detonación de una bomba de aviación de 250 kg de la Segunda Guerra Mundial
# (Múnich, 2012), grabada a 300 m.
at = onset("boom_ww2_bomb.ogg", 29.46)
shot("explosion_real.ogg", "boom_ww2_bomb.ogg", at, 2.8, 1.1, -1.5, 0.002, "highpass=f=30", drive=5.0)

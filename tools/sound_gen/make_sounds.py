#!/usr/bin/env python3
"""Sintetiza por código los bucles de motor del juego (no va en el APK).

Genera en assets/audio: engine_tank.wav, engine_heavy.wav, tracks.wav,
plane_bomber.wav, plane_fighter.wav y helicopter.wav, con su .import en bucle.

Todo se filtra en el dominio de la frecuencia (FFT circular) y todos los eventos se
colocan módulo la duración, así que el final de cada archivo enlaza con su principio
sin chasquido. Los motores llevan su energía entre 150 Hz y 3 kHz para que se oigan
en el altavoz de un móvil, que apenas reproduce graves.

Uso: python3 tools/sound_gen/make_sounds.py
"""
import hashlib
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")


def spectrum_filter(x, gain):
    """Filtra `x` multiplicando su espectro por gain(frecuencias). Circular: no rompe el bucle."""
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x) * gain(freqs), len(x))


def band(lo, hi, slope=4.0):
    """Paso banda suave entre lo y hi (Hz)."""
    def gain(f):
        f = np.maximum(f, 1e-6)
        return 1.0 / np.sqrt(1.0 + (lo / f) ** (2 * slope)) / np.sqrt(1.0 + (f / hi) ** (2 * slope))
    return gain


def peaks(centres, widths, gains, floor=0.25):
    """Resonancias (formantes) sobre un suelo plano."""
    def gain(f):
        total = np.full_like(f, floor)
        for c, w, g in zip(centres, widths, gains):
            total += g * np.exp(-0.5 * ((f - c) / w) ** 2)
        return total
    return gain


def circular_convolve(x, kernel):
    padded = np.zeros(len(x))
    n = min(len(kernel), len(x))
    padded[:n] = kernel[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(padded), len(x))


def add_event(buffer, start, event):
    """Suma `event` en `buffer` a partir de `start`, dando la vuelta al llegar al final."""
    idx = (int(start) + np.arange(len(event))) % len(buffer)
    np.add.at(buffer, idx, event)


def phone_voicing(x, low_cut=130.0):
    """Recorta los graves que un móvil no reproduce y refuerza los medios."""
    def gain(f):
        return band(low_cut, 6000.0, 2.0)(f) * (1.0 + 1.3 * np.exp(-0.5 * ((f - 520.0) / 330.0) ** 2))
    return spectrum_filter(x, gain)


def finish(x, rms_db=-17.0, drive=1.6):
    """Saturación suave, quita la continua y deja un nivel medio común a todos los bucles."""
    x = x - np.mean(x)
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-12)
    x = np.tanh(x * drive * 0.5) / np.tanh(drive * 0.5)
    x = spectrum_filter(x, band(70.0, 6500.0, 3.0))
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-12) * 10 ** (rms_db / 20.0)
    peak = np.max(np.abs(x))
    if peak > 0.89:
        x *= 0.89 / peak
    return x


def piston_engine(seconds, firing_hz, cylinders, formants, rng, grit=0.5, whine_hz=0.0):
    """Motor de pistones: un tren de explosiones desiguales (una por cilindro) que excita
    el escape (formantes), más el ruido mecánico modulado por las mismas explosiones."""
    n = int(SR * seconds)
    firings = int(round(firing_hz * seconds))
    step = n / firings
    pattern = 0.55 + 0.45 * rng.random(cylinders)
    pattern[0] = 1.0
    train = np.zeros(n)
    for i in range(firings):
        amp = pattern[i % cylinders] * (1.0 + 0.18 * rng.standard_normal())
        pos = (i + 0.035 * rng.standard_normal()) * step
        train[int(pos) % n] += amp
    t = np.arange(int(SR * 0.12)) / SR
    # Golpe de escape: un chasquido con cola grave.
    pulse = np.exp(-t / 0.004) - 0.6 * np.exp(-t / 0.011) + 0.5 * np.exp(-t / 0.03) * np.sin(2 * np.pi * firing_hz * 2.0 * t)
    exhaust = circular_convolve(train, pulse)
    exhaust = spectrum_filter(exhaust, peaks(formants, [f * 0.22 for f in formants], [3.0, 2.6, 2.0, 1.2][: len(formants)], 0.12))
    exhaust = spectrum_filter(exhaust, band(60.0, 3200.0, 2.0))
    # Ruido mecánico (válvulas, engranajes, admisión) que late con las explosiones.
    envelope = circular_convolve(train, np.exp(-t / 0.012))
    envelope = envelope / np.max(envelope)
    noise = spectrum_filter(rng.standard_normal(n), band(350.0, 3000.0, 2.0))
    noise = noise / np.std(noise)
    mech = noise * (0.25 + envelope)
    rumble = spectrum_filter(rng.standard_normal(n), band(90.0, 260.0, 3.0))
    rumble = rumble / np.std(rumble)
    exhaust = exhaust / np.std(exhaust)
    mix = exhaust + grit * mech + 0.35 * rumble
    if whine_hz > 0.0:
        # Silbido de la transmisión, afinado para que cierre el bucle.
        f = round(whine_hz * seconds) / seconds
        tt = np.arange(n) / SR
        mix += 0.10 * np.sin(2 * np.pi * f * tt + 0.6 * np.sin(2 * np.pi * tt * 2.0 / seconds))
    return phone_voicing(finish(mix, drive=2.2))


def tracks(seconds, clank_hz, rng):
    """Orugas: golpeteo metálico de los eslabones, rodadura y algún chirrido."""
    n = int(SR * seconds)
    clanks = int(round(clank_hz * seconds))
    step = n / clanks
    out = np.zeros(n)
    t = np.arange(int(SR * 0.09)) / SR
    for i in range(clanks):
        amp = (1.0 if i % 2 == 0 else 0.7) * (1.0 + 0.25 * rng.standard_normal())
        clank = np.zeros(len(t))
        for base in (1150.0, 1870.0, 2630.0, 3450.0):
            f = base * (1.0 + 0.05 * rng.standard_normal())
            clank += rng.uniform(0.5, 1.0) * np.exp(-t / rng.uniform(0.010, 0.022)) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28))
        clank += 1.5 * np.exp(-t / 0.006) * rng.standard_normal(len(t))
        add_event(out, (i + 0.06 * rng.standard_normal()) * step, amp * clank)
    out = spectrum_filter(out, band(700.0, 5200.0, 2.0))
    out = out / np.std(out)
    tt = np.arange(n) / SR
    roll = spectrum_filter(rng.standard_normal(n), band(160.0, 900.0, 2.0))
    roll = roll / np.std(roll) * (0.7 + 0.3 * np.sin(2 * np.pi * clanks / seconds * tt))
    # Dos chirridos de metal sin engrasar.
    squeal = np.zeros(n)
    ts = np.arange(int(SR * 0.28)) / SR
    for start, f0 in ((0.31, 2250.0), (1.27, 1980.0)):
        glide = f0 * (1.0 + 0.06 * np.sin(2 * np.pi * 3.0 * ts))
        phase = 2 * np.pi * np.cumsum(glide) / SR
        add_event(squeal, start * SR, np.hanning(len(ts)) * np.sin(phase))
    return finish(0.9 * out + 0.9 * roll + 0.22 * squeal, drive=1.4)


def propeller_plane(seconds, blade_hz, rng, harmonics=22, growl=0.0, wash=0.25):
    """Avión de hélice: cada motor es una serie de armónicos del paso de pala; al sumar
    motores a revoluciones casi iguales aparece el batido (el zumbido que va y viene)."""
    n = int(SR * seconds)
    tt = np.arange(n) / SR
    mix = np.zeros(n)
    for hz in blade_hz:
        f0 = round(hz * seconds) / seconds
        weight = rng.uniform(0.8, 1.0)
        for k in range(1, harmonics + 1):
            f = f0 * k
            if f > 4500.0:
                break
            # Más cuerpo entre 200 y 900 Hz, donde suena el escape.
            amp = k ** -0.85 * (1.0 + 1.8 * np.exp(-0.5 * ((f - 480.0) / 260.0) ** 2))
            mix += weight * amp * np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28))
        if growl > 0.0:
            # Escapes: serie a 1,5 veces el paso de pala, que da el gruñido de un caza.
            g0 = round(hz * 1.5 * seconds) / seconds
            for k in range(1, 12):
                mix += growl * weight * k ** -1.1 * np.sin(2 * np.pi * g0 * k * tt + rng.uniform(0, 6.28))
    mix = mix / np.std(mix)
    noise = spectrum_filter(rng.standard_normal(n), band(250.0, 3200.0, 2.0))
    noise = noise / np.std(noise)
    flutter = 1.0 + 0.35 * np.sin(2 * np.pi * tt * round(blade_hz[0] * seconds) / seconds)
    return phone_voicing(finish(mix + wash * noise * flutter, drive=1.8), 90.0)


def helicopter(seconds, blade_hz, rng):
    """Helicóptero: el golpe de cada pala, el motor y el soplido del rotor."""
    n = int(SR * seconds)
    tt = np.arange(n) / SR
    thumps = int(round(blade_hz * seconds))
    step = n / thumps
    out = np.zeros(n)
    t = np.arange(int(SR * 0.07)) / SR
    shape = (t / 0.008) * np.exp(1.0 - t / 0.008)
    for i in range(thumps):
        thump = shape * (np.sin(2 * np.pi * 105.0 * t) + 0.7 * np.sin(2 * np.pi * 212.0 * t) + 0.9 * rng.standard_normal(len(t)))
        add_event(out, i * step, (1.0 + 0.1 * rng.standard_normal()) * thump)
    out = spectrum_filter(out, band(110.0, 1500.0, 2.0))
    out = out / np.std(out)
    engine = np.zeros(n)
    f0 = round(142.0 * seconds) / seconds
    for k in range(1, 14):
        engine += k ** -1.0 * np.sin(2 * np.pi * f0 * k * tt + rng.uniform(0, 6.28))
    engine = engine / np.std(engine)
    beat = 0.5 + 0.5 * np.cos(2 * np.pi * thumps / seconds * tt)
    wash = spectrum_filter(rng.standard_normal(n), band(700.0, 3500.0, 2.0))
    wash = wash / np.std(wash) * (0.3 + 0.7 * beat ** 2)
    return phone_voicing(finish(1.2 * out + 0.45 * engine + 0.5 * wash, drive=1.6), 110.0)


def save(name, samples):
    path = os.path.join(OUT, name + ".wav")
    samples = samples / np.sqrt(np.mean(samples ** 2)) * 10 ** (-17.0 / 20.0)
    samples = samples * min(1.0, 0.89 / np.max(np.abs(samples)))
    data = np.clip(samples * 32767.0, -32767, 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    res = "res://assets/audio/%s.wav" % name
    digest = hashlib.md5(res.encode()).hexdigest()
    with open(path + ".import", "w") as f:
        f.write(
            '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n'
            'path="res://.godot/imported/%s.wav-%s.sample"\n\n'
            '[deps]\n\nsource_file="%s"\n'
            'dest_files=["res://.godot/imported/%s.wav-%s.sample"]\n\n'
            "[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\n"
            "force/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\n"
            "edit/loop_mode=2\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=2\n"
            % (name, digest, res, name, digest)
        )
    jump = abs(float(samples[0] - samples[-1]))
    print("%-16s %.1f s  rms %.1f dB  pico %.2f  salto de bucle %.4f" % (
        name, len(samples) / SR, 20 * np.log10(np.sqrt(np.mean(samples ** 2))), np.max(np.abs(samples)), jump))


def main():
    rng = np.random.default_rng(1944)
    save("engine_tank", piston_engine(3.0, 34.0, 12, [150.0, 330.0, 700.0, 1400.0], rng, grit=0.55, whine_hz=610.0))
    save("engine_heavy", piston_engine(3.0, 26.0, 12, [120.0, 260.0, 540.0, 1100.0], rng, grit=0.7, whine_hz=470.0))
    save("tracks", tracks(2.0, 14.0, rng))
    save("plane_bomber", propeller_plane(4.0, [82.0, 84.5, 86.25, 88.75], rng, wash=0.3))
    save("plane_fighter", propeller_plane(3.0, [118.0], rng, harmonics=26, growl=0.7, wash=0.35))
    save("helicopter", helicopter(2.0, 13.0, rng))


if __name__ == "__main__":
    main()

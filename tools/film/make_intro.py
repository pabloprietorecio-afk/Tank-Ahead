"""Completa el fogonazo final del vídeo y añade el título «A / TANK / STORY», una palabra por
cañonazo. Uso: make_intro.py VIDEO FUENTE.ttf CARPETA_AUDIO SALIDA.mp4

VIDEO: el clip de la pantalla de carga convertida en carro real que acaba al empezar el fogonazo
(hecho con PixVerse a partir de tools/film/loading_film.tscn). Si trae franjas negras, se quitan.
FUENTE: una tipografía de máquina de escribir; se usó Special Elite (Astigmatic, licencia Apache 2.0),
https://github.com/google/fonts/tree/main/apache/specialelite
CARPETA_AUDIO: assets/audio del juego (cannon.ogg, distant_gun_1.ogg, explosion_real.ogg)."""
import subprocess, sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC, FONT, AUDIO, OUT = sys.argv[1:5]
W, H, FPS = 1280, 720, 24
BG = np.array([13, 15, 13], dtype=np.float32)          # el negro verdoso de la pantalla de carga
INK = np.array([232, 224, 199], dtype=np.float32)      # su tinta crema
HOT = np.array([255, 236, 190], dtype=np.float32)
rng = np.random.default_rng(7)

def probe_crop(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", "3", "-i", path, "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True, check=True).stdout
    info = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", path], capture_output=True, text=True, check=True).stdout.strip().split(",")
    w, h = int(info[0]), int(info[1])
    a = np.frombuffer(raw, dtype=np.uint8).reshape(h, w).astype(np.float32)
    rows = np.where(a.mean(axis=1) > 8)[0]; cols = np.where(a.mean(axis=0) > 8)[0]
    return cols.min(), rows.min(), cols.max() - cols.min() + 1, rows.max() - rows.min() + 1

x0, y0, cw, ch = probe_crop(SRC)
ch -= ch % 2; cw -= cw % 2
# Se quitan las franjas negras, se amplía hasta 720 de alto y se recorta el sobrante de los lados.
vf = f"crop={cw}:{ch}:{x0}:{y0},scale=-2:{H}:flags=lanczos,crop={W}:{H},unsharp=5:5:0.6"
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", SRC, "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
src = np.frombuffer(raw, dtype=np.uint8).reshape(-1, H, W, 3)
N = len(src)
print("fuente:", N, "cuadros; zona útil", cw, "x", ch)

# Dónde y cuándo empieza el fogonazo: el primer cuadro del final que se enciende de golpe.
lum = src.reshape(N, -1, 3).mean(axis=(1, 2))
onset = N - 1
for i in range(N - 1, max(N - 20, 1), -1):
    if lum[i] - lum[i - 1] > 12:
        onset = i
# Su centro: lo que está al blanco en el último cuadro (la boca del cañón), no el carro iluminado.
bright = src[-1].astype(np.float32).mean(axis=2)
diff = np.clip(bright - max(float(np.percentile(bright, 99.3)) - 4.0, 200.0), 0, None)
ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
fx, fy = float((xs * diff).sum() / diff.sum()), float((ys * diff).sum() / diff.sum())
print("fogonazo: cuadro", onset, "centro", round(fx), round(fy))

def radial(cx, cy, radius):
    return np.exp(-(((xs - cx) ** 2 + (ys - cy) ** 2) / (radius * radius)))[..., None]

def noise_field(scale, seed):
    r = np.random.default_rng(seed)
    small = r.random((H // scale + 3, W // scale + 3)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((W * 2, H * 2), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0

SMOKE = 0.55 * noise_field(190, 1) + 0.3 * noise_field(90, 2) + 0.15 * noise_field(40, 3)
vignette = 1.0 - 0.55 * np.clip(((xs - W / 2) / (W * 0.62)) ** 2 + ((ys - H / 2) / (H * 0.62)) ** 2, 0, 1)[..., None]

frames = [f for f in src]

# 1) El fogonazo se abre hasta llenar la pantalla…
last = src[-1].astype(np.float32)
BLOOM = 6
for n in range(BLOOM):
    t = (n + 1) / BLOOM
    glow = radial(fx, fy, 160 + 900 * t * t) * (1.4 + 3.5 * t)
    img = last + glow * HOT * (0.9 + 1.6 * t) + 255.0 * max(t - 0.55, 0.0) * 2.2
    frames.append(np.clip(img, 0, 255).astype(np.uint8))
# …y se apaga hacia el fondo oscuro del título: del blanco al naranja, primero por los bordes.
DECAY = 11
for n in range(DECAY):
    t = (n + 1) / DECAY
    heat = (1 - t) ** 1.5
    color = np.array([255, 245 - 150 * t, 215 - 215 * min(t * 1.4, 1)], dtype=np.float32)
    core = radial(fx, fy, 1100 * (1 - 0.72 * t) + 60)
    img = BG + (color - BG) * np.clip(core * heat * 1.25, 0, 1)
    frames.append(np.clip(img * (0.75 + 0.25 * vignette), 0, 255).astype(np.uint8))
title_start = len(frames)

# 2) El título: una palabra por cañonazo, a máquina.
WORDS = ["A", "TANK", "STORY"]
SIZE = 176
font = ImageFont.truetype(FONT, SIZE)
LINE = 172
tops = [H / 2 + (i - 1) * LINE for i in range(3)]

def word_layer(text, scale):
    f = ImageFont.truetype(FONT, int(SIZE * scale))
    box = f.getbbox(text)
    w, h = box[2] - box[0], box[3] - box[1]
    img = Image.new("L", (w + 40, h + 40), 0)
    ImageDraw.Draw(img).text((20 - box[0], 20 - box[1]), text, font=f, fill=255)
    return np.asarray(img).astype(np.float32) / 255.0

# Tinta desigual, como una cinta gastada: se come un poco los trazos aquí y allá.
WEAR = np.clip(0.72 + 0.5 * noise_field(9, 11)[:H, :W], 0, 1)

HITS = [8, 27, 46]
HOLD_AFTER = 54
FADE = 12
TITLE_FRAMES = HITS[-1] + HOLD_AFTER + FADE
for n in range(TITLE_FRAMES):
    canvas = np.tile(BG, (H, W, 1)).astype(np.float32)
    flash = np.zeros((H, W, 1), dtype=np.float32)
    shake = np.zeros(2)
    ink = np.zeros((H, W), dtype=np.float32)
    heat_mask = np.zeros((H, W), dtype=np.float32)
    for i, hit in enumerate(HITS):
        k = n - hit
        if k < 0:
            continue
        punch = math.exp(-k / 1.5)
        layer = word_layer(WORDS[i], 1.0 + 0.2 * punch)
        lh, lw = layer.shape
        cx, cy = W / 2, tops[i]
        x, y = int(cx - lw / 2), int(cy - lh / 2)
        xa, ya, xb, yb = max(x, 0), max(y, 0), min(x + lw, W), min(y + lh, H)
        part = layer[ya - y:yb - y, xa - x:xb - x]
        ink[ya:yb, xa:xb] = np.maximum(ink[ya:yb, xa:xb], part)
        heat_mask[ya:yb, xa:xb] = np.maximum(heat_mask[ya:yb, xa:xb], part * math.exp(-k / 3.0))
        flash += radial(cx, cy, 520 + 500 * punch) * 1.15 * math.exp(-k / 1.7)
        amp = 15.0 * math.exp(-k / 2.4)
        shake += rng.uniform(-1, 1, 2) * amp
    level = float(np.clip(flash.max(), 0, 1))
    # Humo que deriva despacio y se enciende con cada disparo.
    ox, oy = int(n * 2.4) % W, int(n * 0.9) % H
    smoke = SMOKE[oy:oy + H, ox:ox + W][..., None]
    canvas += smoke * np.array([54, 48, 40], dtype=np.float32) * (0.5 + 2.6 * level) * (0.35 + 0.65 * (n > HITS[0]))
    # Resplandor naranja detrás de la palabra recién disparada.
    halo = np.asarray(Image.fromarray((heat_mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(26))).astype(np.float32) / 255.0
    canvas += halo[..., None] * np.array([255, 150, 50], dtype=np.float32) * 0.9
    worn = (ink * WEAR)[..., None]
    color = INK + (np.array([255, 255, 245], dtype=np.float32) - INK) * heat_mask[..., None]
    canvas = canvas * (1 - worn) + color * worn
    canvas += flash * HOT
    canvas *= vignette
    canvas += rng.normal(0, 1.6, (H, W, 1)).astype(np.float32)      # grano
    img = np.clip(canvas, 0, 255).astype(np.uint8)
    dx, dy = int(round(shake[0])), int(round(shake[1]))
    if dx or dy:
        # Sacudida: se desplaza la imagen y el hueco se rellena con el borde, sin dar la vuelta.
        img = np.roll(img, (dy, dx), axis=(0, 1))
        if dy > 0: img[:dy] = img[dy:dy + 1]
        if dy < 0: img[dy:] = img[dy - 1:dy]
        if dx > 0: img[:, :dx] = img[:, dx:dx + 1]
        if dx < 0: img[:, dx:] = img[:, dx - 1:dx]
    if n >= TITLE_FRAMES - FADE:
        img = (img.astype(np.float32) * ((TITLE_FRAMES - 1 - n) / FADE)).astype(np.uint8)
    frames.append(img)

total = len(frames)
print("cuadros:", total, "duración", round(total / FPS, 2), "s")

# Sonido: el del vídeo y, encima, un cañonazo en el fogonazo y otro por palabra (los del juego).
shots = [(onset / FPS, 1.0, 1.0)] + [((title_start + h) / FPS, p, 1.0) for h, p in zip(HITS, (1.0, 0.94, 0.88))]
inputs = ["-i", SRC]
filt = [f"[0:a]afade=t=out:st={N / FPS - 0.12:.3f}:d=0.12,apad[a0]"]
mix = ["[a0]"]
idx = 1
for at, pitch, gain in shots:
    for name, vol, extra in (("cannon.ogg", 1.25 * gain, ""), ("distant_gun_1.ogg", 1.5 * gain, ",lowpass=f=220")):
        inputs += ["-i", os.path.join(AUDIO, name)]
        filt.append(f"[{idx}:a]aresample=44100,asetrate={int(44100 * pitch)},aresample=44100,volume={vol}{extra},adelay={int(at * 1000)}:all=1[s{idx}]")
        mix.append(f"[s{idx}]"); idx += 1
# El último deja cola: la explosión real del juego, por debajo.
inputs += ["-i", os.path.join(AUDIO, "explosion_real.ogg")]
filt.append(f"[{idx}:a]aresample=44100,volume=0.7,adelay={int(shots[-1][0] * 1000 + 60)}:all=1[s{idx}]")
mix.append(f"[s{idx}]")
filt.append("".join(mix) + f"amix=inputs={len(mix)}:normalize=0:duration=longest,alimiter=limit=0.7:level=false:attack=2:release=80,afade=t=out:st={total / FPS - 0.6:.3f}:d=0.6,atrim=0:{total / FPS:.3f}[aout]")
cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-"] + inputs + [
    "-filter_complex", ";".join(f.replace("[0:a]", "[1:a]") if False else f for f in filt),
    "-map", "0:v", "-map", "[aout]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "21", "-preset", "slow", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", OUT]
# El vídeo en bruto entra por la tubería como entrada 0: los índices de audio se corren uno.
shifted = []
for f in filt:
    for j in range(idx, -1, -1):
        f = f.replace(f"[{j}:a]", f"[{j + 1}:a]")
    shifted.append(f)
cmd[cmd.index("-filter_complex") + 1] = ";".join(shifted)
p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
for f in frames:
    p.stdin.write(f.tobytes())
p.stdin.close()
print("ffmpeg:", p.wait())

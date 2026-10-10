"""Procedural WWE-style arena sound for the promo (numpy/scipy, no external samples).

Everything is synthesised so there are no licence questions: ring bell, crowd
roar, heavy slam hits, whooshes, risers and a stomp-clap arena-rock bed.

    render(events, total, out_wav, bpm)

`events` is a list of {"t": seconds, "kind": name, "gain": 0..1.5, "pan": -1..1}.
"""
from __future__ import annotations

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- primitives
def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def noise(dur: float) -> np.ndarray:
    return RNG.standard_normal(int(dur * SR))


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="high", fs=SR, output="sos"), x)


def reverb(x, decay=0.5, wet=0.25):
    n = int(decay * SR)
    ir = RNG.standard_normal(n) * np.exp(-np.arange(n) / (decay * SR / 5.0))
    ir = lp(ir, 5000)
    ir[0] = 0
    tail = signal.fftconvolve(x, ir)[: len(x) + n]
    out = np.zeros(len(tail))
    out[: len(x)] += x
    out += tail * wet * (np.max(np.abs(x)) / (np.max(np.abs(tail)) + 1e-9))
    return out


def fit(x, n):
    out = np.zeros(n)
    m = min(n, len(x))
    out[:m] = x[:m]
    return out


def sat(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


# ------------------------------------------------------------------ one-shots
def hit_heavy(power=1.0):
    t = t_axis(0.5)
    f = 42 + 120 * np.exp(-t / 0.045)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (0.11 * power + 0.03))
    crack = bp(noise(0.5), 1200, 7000) * np.exp(-t / 0.018) * 0.9
    thud = bp(noise(0.5), 120, 700) * np.exp(-t / 0.07) * 0.8
    x = sat(body * 1.2 + crack + thud, 2.2 * power + 0.8)
    return reverb(x, 0.35, 0.18) * 0.9


def hit_light():
    t = t_axis(0.25)
    f = 90 + 220 * np.exp(-t / 0.03)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.06)
    crack = bp(noise(0.25), 1800, 8000) * np.exp(-t / 0.012)
    return sat(body + crack * 0.9, 2.0) * 0.8


def boom(long=1.0):
    n = 1.8 * long
    t = t_axis(n)
    f = 36 + 70 * np.exp(-t / 0.18)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.55)
    rumble = lp(noise(n), 300) * np.exp(-t / 0.5) * 2.5
    crash = hp(noise(n), 2500) * np.exp(-t / 0.5) * 0.45
    click = bp(noise(n), 800, 6000) * np.exp(-t / 0.012)
    return reverb(sat(sub * 1.3 + rumble + crash + click * 0.8, 1.8), 1.0, 0.3)


def whoosh(dur=0.35, up=True):
    n = int(dur * SR)
    x = noise(dur)
    out = np.zeros(n)
    chunks = 24
    edges = np.linspace(0, n, chunks + 1).astype(int)
    for i in range(chunks):
        c = i / (chunks - 1)
        c = c if up else 1 - c
        centre = 350 * (13 ** c)
        seg = x[edges[i]: edges[i + 1]]
        if len(seg) < 64:
            continue
        out[edges[i]: edges[i + 1]] = bp(seg, centre * 0.7, min(centre * 1.5, SR / 2 - 100))
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.6
    return out * env * 1.6


def bell(strikes=3, gap=0.19):
    n = 1.6 + gap * strikes
    out = np.zeros(int(n * SR))
    partials = [(1.0, 0.55, 1.0), (2.42, 0.38, 0.6), (3.92, 0.22, 0.45), (5.8, 0.14, 0.3), (8.6, 0.07, 0.2)]
    for k in range(strikes):
        start = int(k * gap * SR)
        t = t_axis(1.6)
        s = np.zeros_like(t)
        for ratio, tau, a in partials:
            s += a * np.sin(2 * np.pi * 540 * ratio * t) * np.exp(-t / tau)
        s += bp(noise(1.6), 2000, 9000) * np.exp(-t / 0.02) * 0.8
        out[start: start + len(s)] += s * (0.85 + 0.15 * (k == strikes - 1))
    return reverb(out * 0.5, 0.7, 0.25)


def crowd(dur=3.0, swell=0.4, peak=0.9):
    n = int(dur * SR)
    t = t_axis(dur)
    x = bp(noise(dur), 250, 2800) + 0.6 * bp(noise(dur), 1200, 5500)
    wob = 1 + 0.35 * lp(noise(dur), 7)  # random crowd flutter
    wob = wob / np.max(np.abs(wob))
    rise = np.clip(t / (dur * swell), 0, 1) ** 1.4
    fall = np.clip((dur - t) / (dur * 0.35), 0, 1)
    env = rise * fall
    return x * wob * env * peak * 0.5


def cheer_burst(dur=1.6):
    return crowd(dur, swell=0.12, peak=1.0)


def riser(dur=1.6):
    t = t_axis(dur)
    x = hp(noise(dur), 1500) * (t / dur) ** 2
    f = 180 * (12 ** (t / dur))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / dur) ** 2.2 * 0.5
    return (x * 0.5 + s) * np.clip((dur - t) / 0.03, 0, 1)


def stomp():
    t = t_axis(0.3)
    f = 55 + 70 * np.exp(-t / 0.03)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)
    wood = bp(noise(0.3), 200, 1400) * np.exp(-t / 0.03) * 0.9
    return reverb(sat(body * 1.4 + wood, 2.0), 0.4, 0.2)


def clap():
    n = int(0.45 * SR)
    out = np.zeros(n)
    for k, d in enumerate([0.0, 0.011, 0.023, 0.036]):
        i = int(d * SR)
        burst = bp(noise(0.4), 900, 6500) * np.exp(-t_axis(0.4) / (0.012 if k < 3 else 0.09))
        out[i: i + len(burst)] += burst[: n - i]
    return reverb(out, 0.5, 0.35) * 0.9


def snare():
    t = t_axis(0.3)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    rattle = bp(noise(0.3), 1500, 9000) * np.exp(-t / 0.09)
    return sat(body * 0.6 + rattle, 1.6) * 0.8


def hat():
    t = t_axis(0.08)
    return hp(noise(0.08), 7000) * np.exp(-t / 0.018) * 0.4


def crash_cym():
    t = t_axis(1.6)
    return hp(noise(1.6), 4500) * np.exp(-t / 0.5) * 0.6


ONE_SHOTS = {
    "hit": lambda: hit_heavy(1.0),
    "hit_big": lambda: hit_heavy(1.6),
    "hit_light": hit_light,
    "boom": lambda: boom(1.0),
    "boom_long": lambda: boom(1.5),
    "whoosh": lambda: whoosh(0.32, True),
    "whoosh_down": lambda: whoosh(0.32, False),
    "whoosh_long": lambda: whoosh(0.6, True),
    "bell": lambda: bell(3, 0.19),
    "bell_single": lambda: bell(1),
    "crowd": lambda: crowd(3.2, 0.35, 0.9),
    "crowd_big": lambda: crowd(4.5, 0.2, 1.0),
    "cheer": cheer_burst,
    "riser": lambda: riser(1.4),
    "riser_long": lambda: riser(2.4),
    "crash": crash_cym,
}


# ----------------------------------------------------------------------- music
def saw(f, dur, detune=0.003):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for d in (-detune, 0.0, detune):
        out += signal.sawtooth(2 * np.pi * f * (1 + d) * t)
    return out / 3


def adsr(n, a=0.005, d=0.05, s=0.8, r=0.03):
    env = np.ones(n)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    env[:ai] = np.linspace(0, 1, max(ai, 1))
    env[ai: ai + di] = np.linspace(1, s, max(di, 1))[: len(env[ai: ai + di])]
    env[ai + di:] = s
    if ri and ri < n:
        env[-ri:] *= np.linspace(1, 0, ri)
    return env


def power_chord(root_hz, dur, gain=1.0, mute=False):
    n = int(dur * SR)
    notes = [root_hz, root_hz * 1.4983, root_hz * 2.0]
    x = sum(saw(f, dur) for f in notes)
    x = sat(lp(x, 3200 if not mute else 1400), 6.0)
    env = adsr(n, 0.004, 0.06 if mute else 0.1, 0.18 if mute else 0.85, 0.02 if mute else 0.08)
    return x * env * gain * 0.35


def bass_note(f, dur, gain=1.0):
    n = int(dur * SR)
    x = lp(saw(f, dur, 0.001), 700) + 0.8 * np.sin(2 * np.pi * f * t_axis(dur))
    return sat(x, 2.2) * adsr(n, 0.004, 0.05, 0.8, 0.04) * gain * 0.55


NOTE = {"E": 41.20, "G": 49.00, "A": 55.00, "C": 65.41, "D": 73.42}


def place(buf, x, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= buf.shape[1] or i < 0:
        return
    m = min(len(x), buf.shape[1] - i)
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    buf[0, i: i + m] += x[:m] * gain * l
    buf[1, i: i + m] += x[:m] * gain * r


def music(total: float, bpm: float, sections: list[dict]) -> np.ndarray:
    """Stomp-clap arena rock. sections: [{"from": s, "to": s, "guitar": 0-1, "bass": 0-1, "drums": 0-1, "hats": bool}]"""
    beat = 60.0 / bpm
    buf = np.zeros((2, int((total + 3) * SR)))
    progression = ["E", "E", "C", "D"]  # per bar; chords are power chords
    drums = {"stomp": stomp(), "clap": clap(), "snare": snare(), "hat": hat(), "crash": crash_cym()}
    n_beats = int(total / beat) + 1
    for b in range(n_beats):
        t = b * beat
        sec = next((s for s in sections if s["from"] <= t < s["to"]), sections[-1])
        bar = b // 4
        root_name = progression[bar % 4]
        root = NOTE[root_name]
        d = sec.get("drums", 1.0)
        g = sec.get("guitar", 0.0)
        ba = sec.get("bass", 0.0)
        step = b % 4
        # stomp stomp clap (rest)
        if d > 0:
            if step in (0, 1):
                place(buf, drums["stomp"], t, 1.0 * d)
            if step == 2:
                place(buf, drums["clap"], t, 0.9 * d)
                place(buf, drums["snare"], t, 0.5 * d)
            if sec.get("hats") and True:
                place(buf, drums["hat"], t, 0.7 * d, 0.2)
                place(buf, drums["hat"], t + beat / 2, 0.5 * d, -0.2)
        if step == 0 and sec.get("crash_on_bar", True) and bar % 4 == 0 and g > 0:
            place(buf, drums["crash"], t, 0.5)
        # bass: eighth-note drive on root
        if ba > 0:
            for k in range(2):
                place(buf, bass_note(root * 2, beat * 0.45), t + k * beat / 2, ba)
        # guitar: palm-muted eighths with open accents on 1
        if g > 0:
            for k in range(2):
                open_chord = (step == 0 and k == 0)
                dur = beat * (0.95 if open_chord else 0.4)
                place(buf, power_chord(root * 4, dur, g * (1.0 if open_chord else 0.8), mute=not open_chord), t + k * beat / 2, 1.0, -0.15 if k else 0.15)
    return buf


# ------------------------------------------------------------------- the mixer
def render(events: list[dict], total: float, out_wav: str, bpm: float, sections: list[dict], music_gain=0.55, with_music: bool = True) -> None:
    n = int((total + 2.5) * SR)
    mus = music(total, bpm, sections)[:, :n] if with_music else np.zeros((2, n))
    fx = np.zeros((2, n))
    base_gain = {"hit": 0.95, "hit_big": 1.0, "hit_light": 0.6, "boom": 0.9, "boom_long": 0.95, "whoosh": 0.4, "whoosh_down": 0.4,
                 "whoosh_long": 0.45, "bell": 0.6, "bell_single": 0.6, "crowd": 0.38, "crowd_big": 0.45, "cheer": 0.45, "riser": 0.4,
                 "riser_long": 0.45, "crash": 0.4}
    cache = {}
    for k, v in ONE_SHOTS.items():
        x = v()
        cache[k] = x / (np.max(np.abs(x)) + 1e-9) * base_gain[k]
    duck = np.ones(n)
    for ev in events:
        s = cache[ev["kind"]]
        place(fx, s, ev["t"], ev.get("gain", 1.0), ev.get("pan", 0.0))
        if ev["kind"] in ("hit", "hit_big", "boom", "boom_long", "bell"):
            i = int(ev["t"] * SR)
            depth = 0.55 if ev["kind"] != "hit" else 0.7
            ln = int(0.28 * SR)
            duck[i: i + ln] = np.minimum(duck[i: i + ln], np.linspace(depth, 1.0, min(ln, len(duck[i:]))))
    mus = mus * duck * music_gain
    mix = mus + fx
    mix = mix[:, : int(total * SR)]
    peak = np.max(np.abs(mix))
    mix = np.tanh(mix / (peak * 0.9 + 1e-9) * 1.1) * 0.9
    wavfile.write(out_wav, SR, (mix.T * 32767).astype(np.int16))

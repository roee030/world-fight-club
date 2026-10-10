"""Assemble the 22.5 s Hebrew promo from recorded gameplay clips.

    python tools/promo/timeline_gen.py          # regenerate timeline.json (beats, captions, cues)
    python tools/promo/build_trailer.py [--clips output/promo/clips_v4] [--only h|v]

Pipeline: trim/zoom each clip -> xfade chain with whip-pan blur and flashes ->
animated Hebrew overlays (overlays.py) -> procedural WWE-style soundtrack (sound.py).
Outputs in output/promo/final/: trailer_16x9.mp4, trailer_9x16.mp4.
The recorded clips' own audio is only used to find hit timings; it is not in the cut.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import intro  # noqa: E402
import overlays as ov  # noqa: E402
import sound  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "promo"
URL = "roee030.github.io/world-fight-election"
FFMPEG = "ffmpeg"
TL = json.loads((Path(__file__).parent / "timeline.json").read_text(encoding="utf-8"))


def run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        print(" ".join(cmd)[:1500])
        print(proc.stderr[-3000:])
        raise SystemExit(proc.returncode)


# ------------------------------------------------------------------ timeline math
def layout() -> None:
    t = 0.0
    segs = TL["segments"]
    for i, s in enumerate(segs):
        s["start"] = t
        t += s["dur"]
        s["end"] = t
        s["d_out"] = (s["tr"] or {}).get("d", 0.0)
        s["d_in"] = segs[i - 1]["tr"]["d"] if i > 0 and segs[i - 1]["tr"] else 0.0
        s["pre"] = s["d_in"] / 2
        s["post"] = s["d_out"] / 2


# ------------------------------------------------------------------ segments
def make_segment(clips: Path, s: dict, out: Path) -> None:
    pre, post = s["pre"], s["post"]
    length = s["dur"] + pre + post
    speed = float(s.get("speed", 1.0))
    vf = ["fps=60"]
    if abs(speed - 1.0) > 1e-3:
        vf.append(f"setpts=PTS/{speed:.5f}")
    if s.get("crop"):
        cw, ch, cx, cy = s["crop"].split(":")
        vf.append(f"crop={cw}:{ch}:{cx}:{cy}")
    vf.append("scale=1920:1080:flags=lanczos")
    punch = float(s.get("punch", 0.07))
    if punch > 0:
        z = f"(1+{punch}*pow(max(0\\,1-(t-{pre:.3f})/0.16)\\,2))"
        vf.append(f"scale=w='trunc(1920*{z}/2)*2':h='trunc(1080*{z}/2)*2':eval=frame:flags=bilinear")
        vf.append("crop=1920:1080")
    if s.get("dim"):
        vf.append(f"eq=brightness=-{s['dim']}:saturation=0.85")
    vf.append("fps=60")
    cmd = [FFMPEG, "-v", "error", "-y", "-ss", f"{max(0.0, s['ss'] - pre * speed):.3f}", "-t", f"{length * speed:.3f}", "-i", str(clips / f"{s['clip']}.avi"),
           "-vf", ",".join(vf), "-t", f"{length:.3f}", "-an", "-r", "60", "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-pix_fmt", "yuv420p", str(out)]
    run(cmd)


def vertical_segment(src: Path, s: dict, out: Path) -> None:
    """Re-frame one 16:9 segment for 9:16: sharp centre over a blurred copy."""
    if s.get("vmode") == "full":
        fg = "[b]scale=1080:-2:flags=lanczos[fg]"
    else:
        cx = float(s.get("vcx", 960))
        x0 = int(max(0, min(1920 - 1280, cx - 640)))
        vy = int(s.get("vy", 0))
        fg = f"[b]crop=1280:{1080 - vy}:{x0}:{vy},scale=1080:-2:flags=lanczos[fg]"
    fc = ("[0:v]split[a][b];"
          "[a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=34,eq=brightness=-0.32:saturation=1.1[bg];"
          + fg + ";[bg][fg]overlay=0:(H-h)/2-40[v]")
    run([FFMPEG, "-v", "error", "-y", "-i", str(src), "-filter_complex", fc, "-map", "[v]", "-r", "60",
         "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-pix_fmt", "yuv420p", str(out)])


def xfade_chain(files: list[Path], out: Path) -> None:
    segs = TL["segments"]
    inputs: list[str] = []
    for f in files:
        inputs += ["-i", str(f)]
    parts = []
    cur = "0:v"
    for k in range(len(files) - 1):
        tr = segs[k]["tr"]
        off = segs[k]["end"] - tr["d"] / 2
        parts.append(f"[{cur}][{k + 1}:v]xfade=transition={tr['type']}:duration={tr['d']}:offset={off:.4f}[x{k}]")
        cur = f"x{k}"
        if tr.get("blur"):
            parts.append(f"[{cur}]avgblur=sizeX={int(tr['blur'])}:sizeY=1:enable='between(t,{off:.4f},{off + tr['d']:.4f})'[bl{k}]")
            cur = f"bl{k}"
    run([FFMPEG, "-v", "error", "-y", *inputs, "-filter_complex", ";".join(parts), "-map", f"[{cur}]", "-r", "60",
         "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-pix_fmt", "yuv420p", str(out)])


def render_intro(s: dict, h_out: Path, v_out: Path, want_h: bool, want_v: bool) -> None:
    """WWE countdown (3, 2, 1, FIGHT) as frames -> mp4 for each canvas."""
    length = s["dur"] + s["post"]
    for canvas, out, want in (("h", h_out, want_h), ("v", v_out, want_v)):
        if not want:
            continue
        frames = OUT / "intro_frames" / canvas
        shutil.rmtree(frames, ignore_errors=True)
        intro.render(canvas, str(frames), length, TL["voice"]["cues"])
        run([FFMPEG, "-v", "error", "-y", "-framerate", "60", "-i", str(frames / "%04d.png"), "-t", f"{length:.3f}", "-r", "60",
             "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-pix_fmt", "yuv420p", str(out)])


def build_bases(clips: Path, want_h: bool, want_v: bool) -> tuple[Path, Path]:
    seg_dir = OUT / "segments"
    shutil.rmtree(seg_dir, ignore_errors=True)
    seg_dir.mkdir(parents=True)
    hs, vs = [], []
    for i, s in enumerate(TL["segments"]):
        h = seg_dir / f"{i:02d}_{s['name']}.mp4"
        v = seg_dir / f"v{i:02d}_{s['name']}.mp4"
        if s["clip"] == "__intro__":
            render_intro(s, h, v, want_h, want_v)
        else:
            make_segment(clips, s, h)
            if want_v:
                vertical_segment(h, s, v)
        hs.append(h)
        if want_v:
            vs.append(v)
    base_h, base_v = OUT / "base_h.mp4", OUT / "base_v.mp4"
    if want_h:
        xfade_chain(hs, base_h)
    if want_v:
        xfade_chain(vs, base_v)
    return base_h, base_v


# ------------------------------------------------------------------ sound
def onsets(clip: Path, ss: float, dur: float, thr: float, gap: float = 0.12) -> list[tuple[float, float]]:
    raw = subprocess.run([FFMPEG, "-v", "error", "-ss", f"{ss:.3f}", "-t", f"{dur:.3f}", "-i", str(clip), "-f", "s16le", "-ac", "1", "-ar", "8000", "-"],
                         capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(float) / 32768
    hop = 160  # 20 ms
    e = np.array([np.sqrt((x[i:i + hop] ** 2).mean()) for i in range(0, len(x) - hop, hop)])
    out: list[tuple[float, float]] = []
    for i in range(1, len(e) - 1):
        if e[i] > thr and e[i] >= e[i - 1] and e[i] > e[i + 1]:
            t = i * hop / 8000
            if not out or t - out[-1][0] >= gap:
                out.append((t, float(e[i])))
    return out


def sound_events(clips: Path) -> list[dict]:
    events = [dict(e) for e in TL["sfx"]]
    for s in TL["segments"]:
        det = s.get("detect")
        if det:
            peaks = onsets(clips / f"{s['clip']}.avi", s["ss"], s["src"], det["thr"])
            top = max((p[1] for p in peaks), default=1.0)
            for t, a in peaks:
                events.append(dict(t=s["start"] + t / s["speed"], kind=det["kind"], gain=det["gain"] * (0.75 + 0.25 * a / top), pan=0.0))
            print(f"  {s['name']}: {len(peaks)} detected cues")
    for s in TL["segments"][:-1]:
        tr = s["tr"]
        t = s["end"] - tr["d"] / 2 - 0.06
        kind = {"zoomin": "whoosh_long", "circleopen": "whoosh_long", "fadewhite": "whoosh_down", "fade": "whoosh_down", "hblur": "whoosh"}.get(tr["type"], "whoosh")
        events.append(dict(t=max(0.0, t), kind=kind, gain=0.9, pan=-0.3 if tr["type"] == "slideright" else 0.3))
        if tr.get("flash"):
            events.append(dict(t=s["end"] - tr["d"] / 2, kind="hit_light", gain=0.55))
    return events


def make_sound(clips: Path) -> tuple[Path, Path]:
    """Returns (main mix, music+voice-only mix). Real music and the countdown voice come from audio_in/."""
    total = TL["total"]
    fx = OUT / "fx.wav"
    sound.render(sound_events(clips), total, str(fx), TL["bpm"], [], with_music=False)
    m, v = TL["music"], TL["voice"]
    music_path, voice_path = OUT / "audio_in" / m["file"], OUT / "audio_in" / v["file"]
    fade = max(0.0, total - 1.8)
    base = (f"[0:a]atrim=duration={total + 0.5},asetpts=PTS-STARTPTS,volume={m['gain']},afade=t=out:st={fade:.3f}:d=1.8[mus];"
            f"[1:a]volume={v['gain']},apad[voc];")
    ins = ["-ss", f"{m['start_in_track']}", "-t", f"{total + 1}", "-i", str(music_path), "-t", f"{v['keep']}", "-i", str(voice_path)]
    outs = []
    for name, with_fx in (("mix_main", True), ("mix_music_only", False)):
        out = OUT / f"{name}.wav"
        if with_fx:
            fc = base + f"[2:a]volume={TL['fx_gain']}[fx];[mus][voc][fx]amix=inputs=3:normalize=0:duration=longest,alimiter=limit=0.9,atrim=duration={total}[o]"
            run([FFMPEG, "-v", "error", "-y", *ins, "-i", str(fx), "-filter_complex", fc, "-map", "[o]", "-ar", "48000", str(out)])
        else:
            fc = base + f"[mus][voc]amix=inputs=2:normalize=0:duration=longest,alimiter=limit=0.9,atrim=duration={total}[o]"
            run([FFMPEG, "-v", "error", "-y", *ins, "-filter_complex", fc, "-map", "[o]", "-ar", "48000", str(out)])
        outs.append(out)
    return outs[0], outs[1]


# ------------------------------------------------------------------ overlays / compose
def flash_sequence(outdir: Path, canvas: str, frames: int = 9) -> int:
    outdir.mkdir(parents=True, exist_ok=True)
    w, h = ov.CANVAS[canvas]
    for i in range(frames):
        a = int(255 * (1 - i / frames) ** 1.6 * 0.85)
        Image.new("RGBA", (w, h), (255, 255, 255, a)).save(outdir / f"{i:04d}.png")
    return frames


def gradient_png(path: Path, canvas: str) -> None:
    w, h = ov.CANVAS[canvas]
    band = int(h * (0.30 if canvas == "h" else 0.2))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h - band, h):
        a = int(245 * min(1.0, ((y - (h - band)) / band) * 1.7) ** 1.1)
        for x in range(w):
            px[x, y] = (4, 7, 14, a)
    img.save(path)


def make_overlays(canvas: str) -> list[dict]:
    d = OUT / "ov" / canvas
    shutil.rmtree(d, ignore_errors=True)
    items: list[dict] = []
    specs = list(TL["overlays"])
    for s in TL["segments"][:-1]:  # transition flashes
        if s["tr"].get("flash"):
            specs.append(dict(type="flash", at=round(s["end"] - 0.05, 3), dur=0.15))
    for i, o in enumerate(specs):
        kind = o["type"]
        sub = d / f"{i:02d}_{kind}"
        at, dur = float(o["at"]), float(o["dur"])
        if kind == "title":
            n = ov.title(canvas, str(sub), dur, o.get("sub", "ELECTION EDITION"), o.get("main", "WORLD FIGHT"))
        elif kind == "kicker":
            anchor = tuple(o["anchor"][canvas]) if "anchor" in o else None
            n = ov.kicker(canvas, str(sub), o["text"], dur, anchor=anchor, size=o.get("size"))
        elif kind == "tag":
            n = ov.nametag(canvas, str(sub), o["left"], o["right"], dur, o.get("versus", "VS"))
        elif kind == "cta":
            n = ov.cta(canvas, str(sub), dur, URL, o.get("line1", "PLAY FREE"), o.get("line2", "IN YOUR BROWSER"))
            sub = Path(str(sub) + "_main")
        elif kind == "disclaimer":
            n = ov.disclaimer(canvas, str(sub), dur, o.get("lines"))
        elif kind == "flash":
            n = flash_sequence(sub, canvas)
        else:
            raise ValueError(kind)
        items.append({"dir": sub, "start": at, "frames": n})
    return items


def compose(base: Path, wav: Path, canvas: str, out: Path) -> None:
    total = float(TL["total"])
    items = make_overlays(canvas)
    grad = OUT / "ov" / f"gradient_{canvas}.png"
    grad.parent.mkdir(parents=True, exist_ok=True)
    gradient_png(grad, canvas)
    inputs = ["-i", str(base)]
    chains = ["[0:v]setsar=1[v0]"]
    idx, cur = 1, "v0"
    for g in TL.get("gradient_spans", []):
        inputs += ["-loop", "1", "-i", str(grad)]
        chains.append(f"[{cur}][{idx}:v]overlay=0:0:enable='between(t,{g[0]:.3f},{g[1]:.3f})'[g{idx}]")
        cur = f"g{idx}"
        idx += 1
    for it in items:
        inputs += ["-itsoffset", f"{it['start']:.3f}", "-framerate", "60", "-i", str(it["dir"] / "%04d.png")]
        chains.append(f"[{cur}][{idx}:v]overlay=0:0:eof_action=pass[o{idx}]")
        cur = f"o{idx}"
        idx += 1
    inputs += ["-i", str(wav)]
    fade_out = max(0.0, total - 0.5)
    chains.append(f"[{idx}:a]loudnorm=I=-14:TP=-1.5:LRA=9,afade=t=out:st={fade_out:.3f}:d=0.5[aout]")
    chains.append(f"[{cur}]fade=t=out:st={total - 0.12:.3f}:d=0.12,format=yuv420p[vout]")
    run([FFMPEG, "-v", "error", "-y", *inputs, "-filter_complex", ";".join(chains), "-map", "[vout]", "-map", "[aout]",
         "-t", f"{total:.3f}", "-r", "60", "-c:v", "libx264", "-crf", "15", "-preset", "slow", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(out)])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips", default=str(OUT / "clips_v4"))
    ap.add_argument("--only", choices=["h", "v"], default=None)
    ap.add_argument("--no-video", action="store_true", help="only re-render the soundtrack wav")
    args = ap.parse_args()
    layout()
    clips = Path(args.clips)
    final = OUT / "final"
    final.mkdir(parents=True, exist_ok=True)
    wav, wav_alt = make_sound(clips)
    if args.no_video:
        return
    want_h, want_v = args.only != "v", args.only != "h"
    base_h, base_v = build_bases(clips, want_h, want_v)
    for canvas, base, name, wanted in (("h", base_h, "trailer_16x9", want_h), ("v", base_v, "trailer_9x16", want_v)):
        if not wanted:
            continue
        compose(base, wav, canvas, final / f"{name}.mp4")
        total = float(TL["total"])
        run([FFMPEG, "-v", "error", "-y", "-i", str(final / f"{name}.mp4"), "-i", str(wav_alt), "-map", "0:v", "-map", "1:a", "-c:v", "copy",
             "-af", f"loudnorm=I=-14:TP=-1.5:LRA=9,afade=t=out:st={total - 0.5:.3f}:d=0.5", "-c:a", "aac", "-b:a", "256k", "-shortest",
             str(final / f"{name}_music_only.mp4")])
    print("total", TL["total"])


if __name__ == "__main__":
    main()

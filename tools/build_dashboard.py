"""Build one self-contained analytics page from GoatCounter.

    python tools/build_dashboard.py            # real data -> output/dashboard.html
    python tools/build_dashboard.py --days 7   # shorter window
    python tools/build_dashboard.py --demo     # fake data, no token needed

The read-only API token comes from the GOATCOUNTER_TOKEN environment variable
or the git-ignored file tools/.goatcounter-token (GoatCounter > Settings > API,
permission "Read statistics"). The page embeds the data, so it needs no server
and never exposes the token.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
import random
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKEN_FILE = ROOT / "tools" / ".goatcounter-token"
TEMPLATE = ROOT / "tools" / "dashboard_template.html"
OUTPUT = ROOT / "output" / "dashboard.html"
ROSTER = ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas",
          "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
STAGES = ["knesset_exterior", "knesset_chamber", "patriots_studio", "friday_studio", "hatzinor_studio", "kaplan_junction"]


def site_code() -> str:
    return json.loads((ROOT / "data" / "site_config.json").read_text(encoding="utf-8"))["goatcounter_code"]


def token() -> str:
    value = os.environ.get("GOATCOUNTER_TOKEN", "").strip()
    if not value and TOKEN_FILE.exists():
        value = TOKEN_FILE.read_text(encoding="utf-8").strip()
    if not value:
        raise SystemExit("No token. Create one in GoatCounter > Settings > API (Read statistics) and save it to "
                         f"{TOKEN_FILE} or set GOATCOUNTER_TOKEN. Use --demo to preview without one.")
    return value


def api(path: str, params: dict | None = None, empty_on_404: bool = False) -> dict:
    url = f"https://{site_code()}.goatcounter.com/api/v0/{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                time.sleep(0.3)  # the API allows about 4 requests per second
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code == 404 and empty_on_404:
                print(f"note: {path} returned 404 (no rows)", flush=True)
                return {}  # GoatCounter answers "not found" when a page or list has no rows
            if error.code == 429 and attempt < 3:
                time.sleep(2 * (attempt + 1))
                continue
            raise SystemExit(f"GoatCounter API error {error.code} on {path}: {error.read().decode('utf-8', 'replace')[:200]}")
    raise SystemExit("GoatCounter API kept rate limiting; try again in a minute.")


def fetch(days: int) -> dict:
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=days)
    window = {"start": start.strftime("%Y-%m-%dT%H:00:00Z"), "end": end.strftime("%Y-%m-%dT%H:00:00Z")}
    counts: dict[str, int] = {}
    daily: dict[str, int] = {}
    seen: list[int] = []
    while True:
        params = {**window, "limit": 100, "group": "day"}
        if seen:
            params["exclude_paths"] = ",".join(str(i) for i in seen)
        page = api("stats/hits", params, empty_on_404=True)
        hits = page.get("hits", [])
        for hit in hits:
            path = str(hit["path"]).lstrip("/")
            counts[path] = counts.get(path, 0) + int(hit["count"])
            seen.append(hit["path_id"])
            if path.startswith("session/start/"):
                for day in hit.get("stats") or []:
                    daily[day["day"]] = daily.get(day["day"], 0) + int(day.get("daily", 0))
        if not hits or not page.get("more") or len(hits) < 100:
            break
    extra = {}
    for key in ("systems", "browsers", "locations", "sizes"):
        extra[key] = api(f"stats/{key}", {**window, "limit": 10}, empty_on_404=True).get("stats", [])
    return {"counts": counts, "daily": sorted(daily.items()), **extra,
            "range": f"{start:%d.%m.%Y} – {end:%d.%m.%Y} ({days} ימים)"}


def demo(days: int) -> dict:
    rng = random.Random(7)
    counts: dict[str, int] = {}

    def add(path: str, n: int) -> None:
        counts[path] = counts.get(path, 0) + max(0, n)

    sessions = 342
    add("session/start/touch", 338)
    add("session/start/desktop", 4)
    add("disclaimer/accepted", 190)
    add("tutorial/start", 110)
    add("tutorial/complete", 70)
    for step, n in (("move", 108), ("jab", 96), ("cross", 84), ("guard", 76)):
        add(f"tutorial/step-{step}", n)
    add("tutorial/skip-at-move", 14)
    add("tutorial/skip-at-guard", 9)
    add("menu/start-fight", 150)
    add("menu/campaign", 48)
    add("menu/rematch", 60)
    add("menu/new-opponent", 25)
    shares = (0.55, 0.38, 0.25, 0.14, 0.06, 0.03, 0.01)
    for minutes, share in zip((1, 3, 5, 10, 20, 30, 60), shares):
        add(f"playtime/{minutes:02d}min", int(sessions * share))
    for where, n in (("in-fight", 70), ("after-result", 40), ("menu-or-select", 55),
                     ("start-screen", 80), ("in-tutorial", 25), ("campaign", 9)):
        add(f"leave/{where}", n)
    weights = [rng.random() + (1.4 if i in (2, 11, 8) else 0) for i in range(len(ROSTER))]
    for _ in range(260):
        pick = rng.choices(ROSTER, weights)[0]
        rival = rng.choice(ROSTER)
        mode = "campaign" if rng.random() < 0.25 else "quick"
        add(f"fight/{mode}/{pick}", 1)
        add(f"rival/{rival}", 1)
        add(f"stage/{rng.choice(STAGES)}", 1)
        add(f"level/{mode}/{rng.choice((0, 1, 2))}", 1)
        if rng.random() < 0.8:
            result = "win" if rng.random() < 0.58 else "loss"
            add(f"result/{mode}/{result}", 1)
            add(f"outcome/{pick}/{result}", 1)
            add(f"round/{rng.choice(('ko', 'timeout', 'finisher'))}", 2)
    for fid in ROSTER:
        add(f"sp/{fid}/hit", rng.randint(2, 14))
        add(f"sp/{fid}/miss", rng.randint(0, 8))
    add("sp-press/ready", 130)
    add("sp-press/not-ready", 90)
    for player, n in (("bibi", 18), ("trump", 12), ("bennet", 18)):
        add(f"campaign/start/{player}", n)
    for step in range(1, 13):
        add(f"campaign/won-{step:02d}-of-12", int(48 * 0.82 ** step))
    add("campaign/complete/bibi", 3)
    add("campaign/complete/trump", 1)
    for name, n in (("founders-rush", 40), ("one-two-finish", 31), ("blue-line", 22)):
        add(f"combo/{name}", n)
    for hits, n in ((2, 90), (3, 55), (4, 30), (5, 12)):
        add(f"combo/hits-{hits}", n)
    add("combo/break-player", 20)
    add("combo/break-cpu", 35)
    for level, n in (("easy", 20), ("normal", 52), ("hard", 31)):
        add(f"settings/difficulty/{level}", n)
    add("settings/disclaimer", 6)
    add("sound/muted", 18)
    add("sound/on", 7)
    add("linkedin/click", 9)
    today = datetime.now(timezone.utc).date()
    span = min(days, 30)
    series = [((today - timedelta(days=span - 1 - i)).isoformat(), rng.randint(5, 90)) for i in range(span)]
    return {"counts": counts, "daily": series, "range": f"דמו ({days} ימים)", "demo": True,
            "systems": [{"name": "Android", "count": 238}, {"name": "iOS", "count": 100}, {"name": "Windows", "count": 4}],
            "browsers": [{"name": "Chrome", "count": 242}, {"name": "Safari", "count": 100}],
            "locations": [{"name": "Israel", "count": 323}, {"name": "United States", "count": 19}],
            "sizes": [{"name": "Phones", "count": 148}, {"name": "Tablets and large phones", "count": 190},
                      {"name": "Computer monitors", "count": 4}]}


def portraits() -> dict[str, str]:
    from PIL import Image
    out = {}
    for fid in ROSTER:
        image = Image.open(ROOT / "assets" / "characters" / "portraits" / f"{fid}.png").convert("RGB")
        image.thumbnail((240, 180))
        buffer = io.BytesIO()
        image.save(buffer, "JPEG", quality=82)
        out[fid] = "data:image/jpeg;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")
    return out


def render(data: dict) -> str:
    data = {**data, "portraits": portraits(), "generated": datetime.now().strftime("%d.%m.%Y %H:%M")}
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    return TEMPLATE.read_text(encoding="utf-8").replace("__DATA__", payload)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--demo", action="store_true")
    parser.add_argument("--out", type=Path, default=OUTPUT)
    args = parser.parse_args()
    page = render(demo(args.days) if args.demo else fetch(args.days))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(page, encoding="utf-8")
    print(f"Wrote {args.out} ({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()

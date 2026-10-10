#!/usr/bin/env bash
# Records every raw gameplay clip for the 15 s promo into output/promo/clips.
# Needs a 1920x1080 viewport, supplied by a temporary override.cfg (deleted at the end).
cd "$(dirname "$0")/../.."
GODOT="tools/godot-portable/Godot_v4.7.2-stable_win64_console.exe"
OUT=output/promo/clips_v4
mkdir -p "$OUT"
printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg' EXIT
rec() { # name seconds args...
  local name=$1 secs=$2; shift 2
  [ -f "$OUT/$name.avi" ] && { echo "skip $name"; return; }
  echo "== $name"
  timeout 400 "$GODOT" --path . --write-movie "$OUT/$name.avi" --fixed-fps 60 --quit-after $((secs*60+240)) \
    --script tools/promo/record_clip.gd -- --seconds=$secs "$@" > "$OUT/$name.log" 2>&1
}
# finisher candidates (match point + low rival HP => KO and victory celebration)
rec fin_bibi      16 --player=bibi            --rival=yair_golan      --stage=knesset_chamber --level=1 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
rec fin_trump     16 --player=trump           --rival=benny_gantz     --stage=patriots_studio --level=1 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
rec fin_lapid     16 --player=yair_lapid      --rival=itamar_ben_gvir --stage=friday_studio   --level=1 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
rec fin_bennet    16 --player=bennet          --rival=bezalel_smotrich --stage=hatzinor_studio --level=1 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
# chain fights: pure gameplay, different pairs and arenas
rec ch_avigdor    9 --player=avigdor          --rival=aryeh_deri      --stage=kaplan_junction  --level=1 --seed=3
rec ch_gantz      9 --player=benny_gantz      --rival=bezalel_smotrich --stage=knesset_chamber --level=1 --seed=4
rec ch_eisenkot   9 --player=gadi_eisenkot    --rival=mansour_abbas   --stage=friday_studio   --level=1 --seed=5
rec ch_golan      9 --player=yair_golan       --rival=joint_list      --stage=patriots_studio  --level=1 --seed=6
rec ch_gvir       9 --player=itamar_ben_gvir  --rival=yair_lapid      --stage=hatzinor_studio  --level=1 --seed=7
rec ch_trump      9 --player=trump            --rival=bennet          --stage=knesset_exterior --level=1 --seed=8
rec ch_trump2     9 --player=trump           --rival=bennet          --stage=friday_studio   --level=1 --seed=11
# campaign ladder screen
rec campaign      5 --mode=campaign --player=bennet
# boss payoff: the ladder ends with Bibi
rec boss_gantz   16 --player=benny_gantz      --rival=bibi            --stage=knesset_chamber --level=2 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
# screens (menu, player select + random rival reveal, arena select)
recs() { # name seconds args...
  local name=$1 secs=$2; shift 2
  [ -f "$OUT/$name.avi" ] && { echo "skip $name"; return; }
  echo "== $name"
  timeout 400 "$GODOT" --path . --write-movie "$OUT/$name.avi" --fixed-fps 60 --quit-after $((secs*60+240))     --script tools/promo/record_screens.gd -- --seconds=$secs "$@" > "$OUT/$name.log" 2>&1
}
recs scr_menu     5 --mode=menu
recs scr_select  11 --mode=select --player=yair_golan
# extra finishers for the 23 s cut
rec fin_golan    16 --player=yair_golan       --rival=avigdor         --stage=knesset_exterior --level=1 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
rec fin_eisenkot 16 --player=gadi_eisenkot    --rival=yair_lapid      --stage=hatzinor_studio  --level=1 --meter=100 --meter_at=2.5 --rival_hp=25 --rounds=1
echo ALL_DONE

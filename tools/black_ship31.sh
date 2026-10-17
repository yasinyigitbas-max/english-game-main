#!/bin/bash
# black_ship31.sh: ship a debug build of English Game (recreated 2026-10-17 during the v31.1 recovery; the original was lost in the snapshot restore).
#   1. build voice.pck / speech.pck / narrator.pck (tools/build_packs.gd) + manifest.json
#   2. export the debug APK (Android preset, --export-debug)
#   3. upload packs + APK as GitHub releases in yasinyigitbas-max/english-game-packs (ONLY with --upload)
# usage: tools/black_ship31.sh <version e.g. 31.1> <packs tag e.g. packs-v33> [--reuse-packs] [--upload]
#   --reuse-packs  don't rebuild packs; download the existing <packs tag> release instead
# Godot runs hold /workspace/godot.lock (noclobber protocol, one Godot at a time).
set -euo pipefail
VER=${1:?version, e.g. 31.1}; PTAG=${2:?packs tag, e.g. packs-v33}; shift 2
REUSE=0; UPLOAD=0
for a in "$@"; do case $a in --reuse-packs) REUSE=1;; --upload) UPLOAD=1;; *) echo "unknown arg $a"; exit 2;; esac; done
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-/workspace/tools/godot472/Godot_v4.7.2-stable_linux.x86_64}
REPO=yasinyigitbas-max/english-game-packs
DL=${DL:-/workspace/dl}; PK="$DL/${PTAG//-/_}"; APK="$DL/english_game_house_v$VER.apk"
LOCK=/workspace/godot.lock
lock() { while true; do
    if [ -f $LOCK ]; then p=$(awk '{print $3}' $LOCK); kill -0 "$p" 2>/dev/null || { echo "stale lock: $(cat $LOCK)"; rm -f $LOCK; }; fi
    if ! pgrep -f '^[^ ]*Godot_v' >/dev/null && ( set -C; echo "ship v$VER $$ $(date +%T)" > $LOCK ) 2>/dev/null; then return; fi
    sleep 3; done; }
unlock() { rm -f $LOCK; }
trap unlock EXIT
# sanity: preset + downloader agree with the requested version / packs tag
grep -q "version/name=\"house.$VER\"" "$ROOT/export_presets.cfg" || { echo "export_presets.cfg version/name is not house.$VER"; exit 1; }
VC=$(sed -n 's/^version\/code=//p' "$ROOT/export_presets.cfg")
grep -q "releases/download/$PTAG/" "$ROOT/scripts/boot/packs.gd" || { echo "scripts/boot/packs.gd BASE_URL does not point at $PTAG"; exit 1; }
mkdir -p "$PK"
if [ $REUSE = 1 ]; then
  gh release download "$PTAG" -R $REPO -D "$PK" --clobber
else
  lock; PACKS_OUT="$PK" "$GODOT" --headless --path "$ROOT" -s tools/build_packs.gd; unlock
  python3 - "$PK" "$PTAG" "$VER" "$REPO" <<'PY'
import sys, os, json, hashlib
pk, tag, ver, repo = sys.argv[1:]
packs = []
for f in ["voice.pck", "speech.pck", "narrator.pck"]:
    p = os.path.join(pk, f)
    packs.append({"file": f, "url": f"https://github.com/{repo}/releases/download/{tag}/{f}",
                  "size": os.path.getsize(p), "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()})
json.dump({"version": tag, "game": f"house.{ver}", "packs": packs}, open(os.path.join(pk, "manifest.json"), "w"), indent=1)
print(open(os.path.join(pk, "manifest.json")).read())
PY
fi
lock; "$GODOT" --headless --path "$ROOT" --export-debug "Android" "$APK"; unlock
ls -l "$APK"; echo "APK: $APK  (house.$VER, versionCode $VC, packs $PTAG)"
if [ $UPLOAD = 1 ]; then
  if [ $REUSE = 0 ]; then
    gh release create "$PTAG" -R $REPO --title "$PTAG (house.$VER)" --notes "Voice packs for house.$VER." "$PK"/voice.pck "$PK"/speech.pck "$PK"/narrator.pck "$PK"/manifest.json
  fi
  gh release create "build-v$VER" -R $REPO --title "build v$VER (house.$VER, vc$VC)" --notes "Debug APK house.$VER / versionCode $VC. Packs: $PTAG." "$APK"
else
  echo "(dry run: nothing uploaded; pass --upload to publish $PTAG and build-v$VER)"
fi

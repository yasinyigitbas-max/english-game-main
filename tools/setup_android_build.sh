#!/bin/bash
# Restore the big Godot template libraries (not in git, >100 MB) into android/build after a fresh clone.
# android/build itself IS tracked: it carries the SherpaTts plugin (src/main/java/com/eh/tts, libs/*/sherpa.aar,
# meta-data in src/main/AndroidManifest.xml). Do NOT run "Install Android Build Template" over it.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TPL=${TPL:-$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip}
cd "$ROOT/android/build"
unzip -n -q "$TPL" 'libs/debug/godot-lib.template_debug.aar' 'libs/release/godot-lib.template_release.aar'
ls -l libs/debug libs/release

#!/bin/bash
# usage: run.sh <mode> <tr 0|1>   (blue v31 QA; lock + pgrep; fresh real save per run; own user:// dir)
mode=$1; tr=$2; tag=en; [ "$tr" = 1 ] && tag=tr
fx=/tmp/qa31b/fx_world.json; [ "$mode" = day3 ] && fx=/tmp/qa31b/fx_day3.json
G=/workspace/tools/godot472/Godot_v4.7.2-stable_linux.x86_64
L=/tmp/qa31b/${mode}_${tag}.log; rm -f $L
while true; do
  if [ -z "$(pgrep -f Godot_v4)" ] && ( set -o noclobber; echo "blue_qa31 $$ $(date +%T)" > /workspace/godot.lock ) 2>/dev/null; then break; fi
  sleep 5
done
cd /workspace/story_blue_qa31
cp $fx /tmp/qa31b/save_${mode}_${tag}.json; rm -rf /tmp/qa31b/photos_save_${mode}_${tag}
for f in tools/qa31b/qa31b.gd scripts/places/cafe.gd scripts/places/shop.gd scripts/places/place_base.gd; do timeout 60 $G --headless --path . --check-only --script res://$f 2>&1 | grep -E "Parse Error" | sed "s#^#CHECK $f: #" >> $L; done
if grep -q "Parse Error" $L; then rm -f /workspace/godot.lock; echo QA31BRUN-CHECKFAIL >> $L; exit 0; fi
XDG_DATA_HOME=/tmp/qa31b/xdg timeout 900 xvfb-run -a -s "-screen 0 1600x720x24" $G --path . --rendering-driver opengl3 --resolution 1600x720 res://tools/qa31b/qa31b.tscn -- --save-path=/tmp/qa31b/save_${mode}_${tag}.json --mode=$mode $([ "$tr" = 1 ] && echo --tr) > $L 2>&1
echo "QA31BRUN EXIT $?" >> $L
rm -f /workspace/godot.lock

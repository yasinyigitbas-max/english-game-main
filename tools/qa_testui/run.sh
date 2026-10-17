#!/bin/bash
# usage: run.sh <tag> <WxH>; honours /workspace/godot.lock (one Godot at a time)
L=/workspace/godot.lock; G=/workspace/tools/godot472/Godot_v4.7.2-stable_linux.x86_64
cd ${PROJ:-/workspace/v33_testui}
while true; do
  if [ -s $L ]; then p=$(awk '{print $3}' $L); if [ -n "$p" ] && kill -0 $p 2>/dev/null; then echo "lock busy: $(cat $L)"; sleep 10; continue; fi; fi
  if pgrep -f Godot_v4.7.2 >/dev/null; then echo "godot running (no lock)"; sleep 10; continue; fi
  break
done
echo "black v33testui $$ $(date +%H:%M:%S) qa_testui $1 $2" > $L
W=${2%x*}; H=${2#*x}
timeout 300 xvfb-run -a -s "-screen 0 ${W}x${H}x24" $G --path . --rendering-driver opengl3 --resolution $2 res://tools/qa_testui/qa_testui.tscn -- --save-path=/tmp/v33testui/save.json --tag=$1 --out=/workspace/v33_testui/qa/ 2>&1 | grep -v "^\s*$" | tail -80
grep -q "v33testui $$" $L 2>/dev/null && rm -f $L

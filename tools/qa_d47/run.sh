#!/bin/bash
# usage: tools/qa_d47/run.sh <day 4|7> [import]   (lock + pgrep; fresh save + user:// per run)
day=$1; G=/workspace/tools/godot472/Godot_v4.7.2-stable_linux.x86_64; R=/workspace/red_v33
while true; do
  if [ -z "$(pgrep -f Godot_v4)" ] && [ ! -e /workspace/godot.lock ] && ( set -o noclobber; echo "red_v33 $$" > /workspace/godot.lock ) 2>/dev/null; then break; fi
  sleep 10
done
cd $R
if [ "$2" = import ]; then timeout 900 $G --headless --path . --import > /tmp/qa_d47/import.log 2>&1; echo "IMPORT EXIT $?" >> /tmp/qa_d47/import.log; fi
L=/tmp/qa_d47/run_d$day.log
python3 tools/qa_d47/make_save.py /tmp/qa_d47/save_d$day.json $day
rm -rf /tmp/qa_d47/xdg_d$day /tmp/qa_d47/shots_d$day
XDG_DATA_HOME=/tmp/qa_d47/xdg_d$day timeout 900 xvfb-run -a -s "-screen 0 1600x720x24" $G --path . --rendering-driver opengl3 --resolution 1600x720 res://tools/qa_d47/qa_d47.tscn -- --save-path=/tmp/qa_d47/save_d$day.json --day=$day > $L 2>&1
echo "RUN EXIT $?" >> $L
grep -q "^red_v33 $$" /workspace/godot.lock && rm -f /workspace/godot.lock

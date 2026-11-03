# Step 8 Mac launch report

- Start: 2026-11-03T16:47:00Z (launch 10:47:08 CST), finish 10:47:09 CST
- Godot exit code: 0 (ran about 1 second)
- PNGs produced: 0 of 13
- Last driver.log line: [0.6] step 1: wait:2
- Cause seen in godot.log: SCRIPT ERROR "Cannot call method 'store_line' on a null value" at shot_driver.gd:44 (_log), called from _process (line 87) via _initialize (line 30). The log file handle was null, so the driver stopped after step 1.
- Window ever visible on screen: not observed (I did not watch the screen); it was positioned at 20000,20000 and lived about 1 s.
- Single launch only; no Godot process left (pgrep -x Godot: none).

#!/usr/bin/env bash
# Long runs that survive a restart: a run is registered under a name, started in the background, and started again
# by `resume` when its machine restarted (or the lid closed) before it finished. The runs themselves keep their place
# (pace.gd checkpoints every few game minutes, ai_player.gd replays its saved moves), so a restart costs minutes.
#   tests/tools/long_run.sh start <name> <command...>   register and start (run it from the project folder; env is kept)
#   tests/tools/long_run.sh resume                       start every registered run that is neither finished nor running
#   tests/tools/long_run.sh status                       one line per run: running, finished or stopped
# Runs are kept in $LONG_RUN_DIR (default /mnt/project-files/runs): <name>.sh (what to run), <name>.log, <name>.done.
set -u
DIR="${LONG_RUN_DIR:-/mnt/project-files/runs}"
mkdir -p "$DIR"

running() { [ -f "$DIR/$1.pid" ] && kill -0 "$(cat "$DIR/$1.pid")" 2>/dev/null; }

launch() {
	local name="$1"
	rm -f "$DIR/$name.done"
	(
		nohup bash -c "bash '$DIR/$name.sh' >> '$DIR/$name.log' 2>&1 && touch '$DIR/$name.done'" > /dev/null 2>&1 &
		echo $! > "$DIR/$name.pid"
	)
	echo "started $name"
}

case "${1:-status}" in
start)
	name="$2"
	shift 2
	{
		echo "cd $(printf '%q' "$PWD")"
		printf '%q ' env "XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}" "$@"
		echo
	} > "$DIR/$name.sh"
	launch "$name"
	;;
resume)
	for f in "$DIR"/*.sh; do
		[ -e "$f" ] || continue
		name="$(basename "$f" .sh)"
		if [ -f "$DIR/$name.done" ]; then continue; fi
		if running "$name"; then echo "$name is running"; else launch "$name"; fi
	done
	;;
status)
	for f in "$DIR"/*.sh; do
		[ -e "$f" ] || continue
		name="$(basename "$f" .sh)"
		if [ -f "$DIR/$name.done" ]; then
			echo "$name: finished"
		elif running "$name"; then
			echo "$name: running"
		else
			echo "$name: stopped (run resume)"
		fi
	done
	;;
*)
	echo "usage: long_run.sh start <name> <command...> | resume | status"
	exit 2
	;;
esac

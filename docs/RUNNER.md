# CI runs on Jon's Mac

Every GitHub Actions job for this repo (`.github/workflows/ci.yml` and `release.yml`) runs on **one self-hosted runner**, Jon's Mac, labelled `self-hosted, macOS, ARM64, solace-mac`, so it uses no paid GitHub minutes. The workflows ask for `runs-on: [self-hosted, solace-mac]`.

**What the Mac needs.** It must be awake and the runner service running for jobs to start (they queue otherwise). A user must be logged in, because the play, layout and menu passes open a real game window (there is no `xvfb` on a Mac; `tests/tools/with_display.sh` runs the command straight through there and under `xvfb-run` on a Linux box). Homebrew's `gh` is needed for the rolling `latest` release step (`brew install gh`), and `python3` for the linter.

**Installed once, then cached.** `tests/tools/setup_godot.sh` downloads Godot 4.7.2 (and, with `templates`, the export templates) into `~/.cache/solace` the first time and only writes a `./godot` launcher after that. The GDScript linter lives in a venv at `~/.cache/solace/venv`. Bumping `GODOT_VERSION` in a workflow downloads the new one beside the old.

**One job at a time.** There is one runner, so jobs run in turn. A newer push to the same branch cancels the run it replaces (`concurrency`).

**Back to GitHub's machines.** Change `runs-on` to `ubuntu-latest` in both workflows; the scripts still work on Linux (`setup_godot.sh` picks the Linux build, `with_display.sh` uses `xvfb-run`).

**Builds.** The Windows `.exe` and the universal macOS `.app` are both exported on the Mac in one job (`release.yml`); the Mac's own `codesign` signs the app ad hoc.

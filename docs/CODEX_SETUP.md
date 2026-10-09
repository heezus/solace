# Setting up Codex on a fresh Mac (or PC)

Two ways. Option A needs nothing installed beyond a browser and is the recommended start.

## Option A: Codex cloud (no local install)
1. Sign in at chatgpt.com/codex with your ChatGPT account.
2. Connect GitHub when prompted and grant access to the private repo `heezus/solace`.
3. Create an environment for `heezus/solace` (configure Godot 4.7 for import and visual engine validation).
4. Start a task with the prompt below. Codex works on its own branch and opens a PR for you.

## Option B: Codex CLI or app on the machine
1. Install Git: on a new Mac, run `git --version` in Terminal and accept the Xcode tools prompt. On Windows install Git for Windows.
2. Install the GitHub CLI and sign in as `heezus`: `brew install gh` (Mac) or `winget install GitHub.cli` (PC), then `gh auth login`.
3. Make Codex's own workspace (never share Claude's checkout):
   ```sh
   mkdir -p ~/Documents/Codex_Workspace && cd ~/Documents/Codex_Workspace
   gh repo clone heezus/solace
   ```
4. Open that `solace` folder in the Codex app, or run `codex` inside it (install: `npm i -g @openai/codex`, needs Node, or use the Codex app).
5. Start with the prompt below.

## Starting prompt
> Read AGENTS.md and docs/HANDOFF.md, then pick up the first item in docs/art/requests.md on a codex/ branch and open a PR.

For visual engine work, install Godot 4.7 standard from godotengine.org. Run import, strict warning checks, lint, logic tests and the scripted graphical play/layout passes before publication. SVG-only edits can be made without Godot, but new raster assets and engine changes require generated import metadata and actual game validation. See AGENTS.md for the expanded visual lane; gameplay and releases remain Claude-owned.

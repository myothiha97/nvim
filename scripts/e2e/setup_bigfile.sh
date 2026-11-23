#!/usr/bin/env bash
# Clone the large real-world projects that perf.py and suite_bigfile.py run on (targets.json),
# pinned to the commits the 2026-11-23 runtime report used, and install what their language
# servers need to resolve imports. Usage: scripts/e2e/setup_bigfile.sh [dest]
#
# To test your own files instead, copy targets.json, point cwd/file/anchor at them and run with
# E2E_TARGETS=/path/to/your-targets.json. Nothing is saved to those files (edits are undone).
set -euo pipefail
dest="${1:-${E2E_BIG:-/tmp/nvim-e2e-big}}"
case "$(basename "$dest")" in
  *e2e*) ;; # it is wiped below: only accept an obviously scratch folder
  *) echo "refusing to wipe '$dest': the folder name must contain 'e2e'" >&2; exit 1 ;;
esac
rm -rf "$dest" && mkdir -p "$dest"
clone() { # name url commit
  mkdir -p "$dest/$1" && (cd "$dest/$1" && git init -q && git fetch -q --depth 1 "$2" "$3" && git checkout -q FETCH_HEAD)
}
clone gotools https://github.com/golang/tools.git d878b739a251f4d4ea125697852a2647722c7abb
clone excalidraw https://github.com/excalidraw/excalidraw.git 9c2e462ec23e54c4cf0493328840d6a27191c674
clone django https://github.com/django/django.git 29d2c0ba4ec475d355f7a18a1a6ab47ddea4a7ca
# gopls (the module) needs a newer Go than many machines have; GOTOOLCHAIN=auto fetches it.
(cd "$dest/gotools/gopls" && GOTOOLCHAIN=auto go mod download)
# vtsls needs node_modules for real types (otherwise every import is `any`).
(cd "$dest/excalidraw" && npx -y yarn@1.22.22 install --frozen-lockfile --ignore-scripts --silent)
echo "large-file fixtures ready in $dest  (targets.json expects /tmp/nvim-e2e-big)"

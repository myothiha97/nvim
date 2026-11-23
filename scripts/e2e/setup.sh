#!/usr/bin/env bash
# Prepare the E2E fixtures in a scratch folder (never inside this repo: the suites edit,
# save and `git checkout` fixture files). Usage: scripts/e2e/setup.sh [dest]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest="${1:-${E2E_FX:-/tmp/nvim-e2e-fx}}"
case "$(basename "$dest")" in
  *e2e*) ;; # it is wiped below: only accept an obviously scratch folder
  *) echo "refusing to wipe '$dest': the folder name must contain 'e2e'" >&2; exit 1 ;;
esac
rm -rf "$dest" && mkdir -p "$dest"
cp -R "$here/fixtures/." "$dest/"
init() { (cd "$dest/$1" && printf '%s\n' "${@:2}" > .gitignore && git init -q && git add -A &&
  git -c user.email=e2e@local -c user.name=e2e commit -qm fixture); }
(cd "$dest/nodeapp" && npm install --silent)
(cd "$dest/jestapp" && npm install --silent)
(cd "$dest/pyapp" && python3 -m venv .venv && .venv/bin/pip install -q pytest)
init goapp
init nodeapp node_modules
init jestapp node_modules
init pyapp .venv __pycache__ .pytest_cache
echo "fixtures ready in $dest  (export E2E_FX=$dest if not the default)"

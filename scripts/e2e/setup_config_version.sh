#!/usr/bin/env bash
# Run an older version of this config side by side, for compare.py ("is it still as fast as in
# June?"). Usage: scripts/e2e/setup_config_version.sh <commit> <appname>   e.g. 9232680 nvim-jun
# - a detached git worktree of <commit> becomes ~/.config/<appname> (NVIM_APPNAME=<appname>)
# - its plugins are installed at ITS lazy-lock.json commits, into ~/.local/share/<appname>
# - its treesitter parsers are built from git at the revisions ITS nvim-treesitter pins
# - Mason is shared with the current config, so language servers are identical
# Needs the full git history (git fetch --unshallow) and tree-sitter (Mason's tree-sitter-cli).
set -euo pipefail
C=$1; A=$2; R="$(cd "$(dirname "$0")/../.." && pwd)"
WT="${TMPDIR:-/tmp}/nvim-cfg-$A"
[ -d "$WT" ] || git -C "$R" worktree add -q --detach "$WT" "$C"
ln -sfn "$WT" ~/.config/"$A"
D=~/.local/share/$A; mkdir -p "$D/lazy"
ln -sfn ~/.local/share/nvim/mason "$D/mason"
LZ=$(python3 -c "import json;print(json.load(open('$WT/lazy-lock.json'))['lazy.nvim']['commit'])")
[ -d "$D/lazy/lazy.nvim" ] || git clone -q --filter=blob:none https://github.com/folke/lazy.nvim.git "$D/lazy/lazy.nvim"
git -C "$D/lazy/lazy.nvim" checkout -q "$LZ"
(cd "$WT" && NVIM_APPNAME=$A NVIM_LAZY_UNLOCK=1 timeout 900 nvim --headless '+Lazy! restore' +qa >/dev/null 2>&1 || true)
# :Lazy restore can leave plugins on newer commits: pin every installed one to the lockfile
python3 - "$WT/lazy-lock.json" "$D/lazy" <<'PY'
import json, os, subprocess, sys
lock, L = json.load(open(sys.argv[1])), sys.argv[2]
git = lambda d, *a: subprocess.run(["git", "-C", d, *a], capture_output=True, text=True).stdout.strip()
for name, v in lock.items():
    d = os.path.join(L, name)
    if os.path.isdir(d) and git(d, "rev-parse", "HEAD") != v["commit"]:
        git(d, "fetch", "-q", "origin", v["commit"]); git(d, "checkout", "-q", v["commit"])
        print(("pinned " if git(d, "rev-parse", "HEAD") == v["commit"] else "COULD NOT PIN ") + name)
PY
git -C "$WT" checkout -q -- lazy-lock.json 2>/dev/null || true
# treesitter parsers at this version's pinned revisions
S=$D/site; TSQ=$D/lazy/nvim-treesitter/runtime/queries; mkdir -p "$S/parser" "$S/parser-info" "$S/queries"
export PATH=$HOME/.local/share/nvim/mason/bin:$PATH
NVIM_APPNAME=$A nvim --headless -c 'lua local ok, p = pcall(require, "nvim-treesitter.parsers"); local o = {}
  for _, l in ipairs({ "go","gomod","gosum","gowork","typescript","tsx","javascript","jsdoc","python","lua","luadoc","regex","comment","printf","json","yaml","toml","bash","markdown","markdown_inline","query","vim","vimdoc","html","css","diff","sql" }) do
    local i = ok and p[l] and p[l].install_info; if i then o[#o+1] = table.concat({ l, i.url, i.revision or i.branch or "HEAD", i.location or "-" }, " ") end
  end io.stdout:write(table.concat(o, "\n") .. "\n")' -c 'qa!' 2>/dev/null |
while read -r lang url rev loc; do
  src="${TMPDIR:-/tmp}/nvim-ts-src/$(basename "$url")-$rev"
  [ -d "$src/.git" ] || { mkdir -p "$src" && git -C "$src" init -q && git -C "$src" fetch -q --depth 1 "$url" "$rev" && git -C "$src" checkout -q FETCH_HEAD; } || { echo "fetch failed: $lang"; continue; }
  d=$src; [ "$loc" != "-" ] && d=$src/$loc
  tree-sitter build -o "$S/parser/$lang.so" "$d" >/dev/null 2>&1 || { echo "build failed: $lang"; continue; }
  printf %s "$rev" > "$S/parser-info/$lang.revision"; [ -d "$TSQ/$lang" ] && ln -sfn "$TSQ/$lang" "$S/queries/$lang"
done
for q in ecma jsx html_tags; do [ -d "$TSQ/$q" ] && ln -sfn "$TSQ/$q" "$S/queries/$q"; done
echo "$A ready: NVIM_APPNAME=$A nvim   (compare.py: --configs now=ab: $A=app:$A)"

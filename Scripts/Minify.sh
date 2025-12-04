#!/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C HOME="/home/${SUDO_USER:-$USER}"
builtin cd -P -- "$(dirname -- "${BASH_SOURCE[0]:-}")" && printf '%s\n' "$PWD" || exit 1
#== Helpers ==
has(){ command -v "$1" &>/dev/null; }
err(){ printf '\e[31m✗\e[0m %s\n' "$*" >&2; exit "${2:-1}"; }
ok(){ printf '\e[32m✓\e[0m %s\n' "$*"; }

#== Sync repo ==
git fetch origin
[[ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]] && git pull --rebase
#== Compile blocklist ==
if has hostlist-compiler; then
  time hostlist-compiler -v -c hostlist-compiler-config.json -o blocklist || err "Compilation failed"
else
  err "hostlist-compiler not found. Install: npm i -g @adguard/hostlist-compiler"
fi

#== Minify function ==
minlist(){
  local f="$1" tmp; tmp=$(mktemp)
  # Atomic pipeline: remove whitelist/0. 0.0. 0/comments/blanks/dupes in one pass
  sed -E '/^@@|^#|^[[:space:]]*$/d; s/^0\. 0\.0\.0[[:space:]]+//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$f" | \
    awk 'NF && ! seen[$0]++' | \
    sort -u > "$tmp"
  [[ -s "$tmp" ]] && mv -f "$tmp" "$f" || { rm -f "$tmp"; err "Minify failed: $f"; }
  ok "Minified: $f ($(wc -l < "$f") entries)"
}

#== Dedupe files ==
dedupe_files(){
  local dir="${1:-.}"
  [[ ! -d "$dir" ]] && return
  printf 'Deduping files in %s...\n' "$dir"
  local -A seen hash file line
  while IFS= read -r line; do
    hash="${line%%  *}"
    file="${line#*  }"
    if [[ -n "${seen[$hash]:-}" ]]; then
      printf 'rm duplicate: %s (keeps %s)\n' "$file" "${seen[$hash]}"
      rm -f "$file"
    else
      seen[$hash]="$file"
    fi
  done < <(find "$dir" -type f -exec md5sum {} + | sort -k1,1)
}

#== Process lists ==
dedupe_files . 
minlist blocklist

#== Commit & push ==
printf -v currentDate '%(%Y-%m-%d)T' -1
printf -v currentTime '%(%H:%M:%S)T' -1
git add -A
if git diff --cached --quiet; then
  ok "No changes to commit"
else
  git commit -m "Blocklist update ${currentDate} ${currentTime}" && git push || err "Push failed"
  ok "Pushed to origin"
fi

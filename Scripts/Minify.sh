#!/usr/bin/env bash
set -eou pipefail; shopt -s nullglob globstar; IFS=$'\n\t'
export LC_ALL=C LANG=C
builtin cd -P -- "$(dirname -- "${BASH_SOURCE[0]:-}")" && printf '%s\n' "$PWD" || exit 1
# https://github.com/ppfeufer/adguard-filter-list/blob/master/compile-hostlist
#============ Helpers ====================
has(){ command -v "$1" &>/dev/null; }
date(){ local x="${1:-%d/%m/%y-%R}"; printf "%($x)T\n" '-1'; }
fcat(){ printf '%s\n' "$(<${1})"; }

#============ Main ====================
# Make sure the local git repo is up to date
git fetch origin
if [[ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]]; then
  git pull --rebase
fi

# Create compiled blocklist
if has hostlist-compiler; then
  time hostlist-compiler -v -c hostlist-compiler-config.json -o blocklist
fi

minlist(){
  local f="$1" success=0; local tmp="${f}.tmp"
  cp -- "$f" "$tmp"
  # Remove all whitelisted entries
  sed -i '/^@@/d' "$tmp" && success=1
  # Remove '0.0.0.0' domains
  sed -Ei 's/^0\.0\.0\.0[[:space:]]+//' "$tmp"  && success=1
  # Comments
  awk '!/^#/' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp" && success=1
  # Remove empty lines
  awk 'NF > 0 {gsub(/^ +| +$/,"")}1' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp" && success=1
  # Whitespace
  sed -Ei 's/^[[:space:]]+//;s/[[:space:]]+$//' "$tmp" && success=1
  # Remove rules that are too long as these are most likely non DNS related rules, see https://github.com/AdguardTeam/AdGuardHome/issues/6003
  #sed -i '/^.\{1024\}./d' blocklist
  # Duplicates
  awk '!seen[$0]++' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp" && success=1
  sort -u "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp" && success=1
  if [[ $success -eq 1 ]]; then
    mv -f "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
}

# Push it to GitHub
printf -v currentDate '%(%Y-%m-%d)T' -1
printf -v currentTime '%(%H:%M:%S)T' -1)
git add -A
git commit -m "Blocklist update ${currentDate} ${currentTime}" && git push

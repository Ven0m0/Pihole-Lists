#!/usr/bin/env bash
export LC_ALL=C
# https://github.com/ppfeufer/adguard-filter-list/blob/master/compile-hostlist

# Make sure the local git repo is up to date
git pull

# Create compiled blocklist
time hostlist-compiler -v -c hostlist-compiler-config.json -o blocklist

# Remove rules that are too long as these are most likely non DNS related rules, see https://github.com/AdguardTeam/AdGuardHome/issues/6003
#sed -i '/^.\{1024\}./d' blocklist

minlist(){
  local f="$1" success=0; local tmp="{f}.tmp"
  cp -- "$f" "$tmp"
  # Remove all whitelisted entries
  sed -i '/^@@/d' "$tmp" && success=1
  # Remove empty lines
  awk '{gsub(/^ +| +$/,"")}1' "$tmp"  && success=1
  # Comments
  awk '!/^#/' "$tmp"  && success=1
  # Whitespace
  sed -Ei 's/^[[:space:]]+//;s/[[:space:]]+$//' "$tmp" && success=1
  # Duplicates
  awk '!seen[$0]++' "$tmp" && success=1
  sort -u "$tmp"  |> "$tmp"
  if [[ $success -eq 1 ]]; then
    mv "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
}

# Date and time
currentDate=`date '+%Y-%m-%d'`
currentTime=`date '+%H:%M:%S'`
# Push it to GitHub
git add *
git commit -m "Blocklist update ${currentDate} ${currentTime}"
git push

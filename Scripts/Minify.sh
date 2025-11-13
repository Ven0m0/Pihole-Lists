#!/usr/bin/env bash
export LC_ALL=C
# https://github.com/ppfeufer/adguard-filter-list/blob/master/compile-hostlist

# Make sure the local git repo is up to date
git pull

# Get OISD list, since the HostlistCompiler can't fetch it for whatever reason » https://github.com/AdguardTeam/HostlistCompiler/issues/58
curl https://big.oisd.nl/ -o ../oisd.txt

# Create compiled blocklist
time hostlist-compiler -v -c hostlist-compiler-config.json -o blocklist

# Remove rules that are too long as these are most likely non DNS related rules, see https://github.com/AdguardTeam/AdGuardHome/issues/6003
#sed -i '/^.\{1024\}./d' blocklist

minlist(){
  local f="$1" success=0; local tmp="{f}.tmp"
  cp -- "$f" "$tmp"
  # Remove all whitelisted entries
  sed -i '/^@@/d' "$tmp" 2>/dev/null && success=1
  # Remove empty lines
  sed -i '/^$/d' "$tmp" 2>/dev/null && success=1
  awk '!seen[$0]++' "$tmp" 2>/dev/null && success=1
  sort -u "$tmp" 2>/dev/null |> "$tmp"
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

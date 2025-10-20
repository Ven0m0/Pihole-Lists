#!/usr/bin/env bash

# https://github.com/ppfeufer/adguard-filter-list/blob/master/compile-hostlist

# Remove all whitelisted entries, this is a blocklist after all
sed -i '/^@@/d' blocklist

# Remove empty lines
sed -i '/^$/d' blocklist


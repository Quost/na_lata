#!/usr/bin/env bash
# Incrementa patch e build number do pubspec.yaml (1.0.0+1 -> 1.0.1+2).
set -euo pipefail
cur=$(grep -E '^version: ' pubspec.yaml | sed 's/version: //')
name=${cur%+*}; build=${cur#*+}
IFS=. read -r ma mi pa <<<"$name"
new="$ma.$mi.$((pa+1))+$((build+1))"
sed -i "s/^version: .*/version: $new/" pubspec.yaml
echo "$new"

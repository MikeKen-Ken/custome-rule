#!/usr/bin/env bash
# note: 将 custome-*.yaml（Mihomo +. 后缀规则）转为 domain 规则集并生成 .mrs
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MIHOMO="${MIHOMO:-./mihomo}"
PUBLISH="${PUBLISH:-./publish}"

if [[ ! -x "$MIHOMO" ]]; then
  echo "error: mihomo 不可执行: $MIHOMO" >&2
  exit 1
fi

rm -rf "$PUBLISH"
mkdir -p "$PUBLISH"

shopt -s nullglob
for src in custome-*.yaml; do
  base="${src%.yaml}"
  mrs="${PUBLISH}/${base}.mrs"

  count=0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*-[[:space:]]*['\"]?\+\\. ]] || continue
    count=$((count + 1))
  done <"$src"

  cp "$src" "$PUBLISH/"

  if [[ "$count" -eq 0 ]]; then
    echo "skip (no rules): $src"
    continue
  fi

  "$MIHOMO" convert-ruleset domain yaml "$src" "$mrs"
  "$MIHOMO" convert-ruleset domain mrs "$mrs" "${PUBLISH}/${base}.list"
  echo "built: $mrs ($count rules)"
done

for src in custome-process-*.list; do
  [[ -f "$src" ]] || continue
  cp "$src" "$PUBLISH/"
  count=0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*PROCESS-NAME(-WILDCARD|-REGEX)?, ]] || continue
    count=$((count + 1))
  done <"$src"
  echo "copied: $src ($count rules)"
done

echo "done. artifacts in $PUBLISH"

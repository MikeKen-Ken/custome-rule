#!/usr/bin/env bash
# note: 将 custome-*.yaml（DOMAIN-SUFFIX 写法）转为 Mihomo domain 规则集并生成 .mrs
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
  tmp="${PUBLISH}/${base}.domain.yaml"
  mrs="${PUBLISH}/${base}.mrs"

  echo "payload:" >"$tmp"
  count=0
  while IFS= read -r line; do
    [[ "$line" =~ DOMAIN-SUFFIX,([^[:space:]#]+) ]] || continue
    domain="${BASH_REMATCH[1]}"
    printf "  - '+.%s'\n" "$domain" >>"$tmp"
    count=$((count + 1))
  done <"$src"

  cp "$src" "$PUBLISH/"

  if [[ "$count" -eq 0 ]]; then
    echo "skip (no rules): $src"
    rm -f "$tmp"
    continue
  fi

  "$MIHOMO" convert-ruleset domain yaml "$tmp" "$mrs"
  "$MIHOMO" convert-ruleset domain mrs "$mrs" "${PUBLISH}/${base}.list"
  rm -f "$tmp"
  echo "built: $mrs ($count rules)"
done

echo "done. artifacts in $PUBLISH"

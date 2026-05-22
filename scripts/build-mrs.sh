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

# 去掉行尾「空白 + #」注释；整行 # 与空行原样保留（源文件可继续写说明）
strip_trailing_comment() {
  local line="$1"
  if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
    printf '%s\n' "$line"
    return
  fi
  case "$line" in
    *' #'*)
      line="${line%% #*}"
      line="${line%"${line##*[![:space:]]}"}"
      ;;
  esac
  printf '%s\n' "$line"
}

write_stripped_file() {
  local src="$1" dest="$2"
  while IFS= read -r line || [[ -n "$line" ]]; do
    strip_trailing_comment "$line"
  done <"$src" >"$dest"
}

rm -rf "$PUBLISH"
mkdir -p "$PUBLISH"

# Mihomo +. 域名规则行：- '+.example' / - "+.example" / - +.example
_custome_plus_domain_re='^[[:space:]]*-[[:space:]]*["'\'']?\+\.'

shopt -s nullglob
for src in custome-*.yaml; do
  base="${src%.yaml}"
  mrs="${PUBLISH}/${base}.mrs"
  publish_yaml="${PUBLISH}/${src}"
  list_out="${PUBLISH}/${base}.list"

  count=0
  while IFS= read -r line; do
    [[ "$line" =~ $_custome_plus_domain_re ]] || continue
    count=$((count + 1))
  done <"$src"

  write_stripped_file "$src" "$publish_yaml"

  if [[ "$count" -eq 0 ]]; then
    echo "skip (no rules): $src"
    continue
  fi

  "$MIHOMO" convert-ruleset domain yaml "$publish_yaml" "$mrs"
  "$MIHOMO" convert-ruleset domain mrs "$mrs" "$list_out"
  write_stripped_file "$list_out" "${list_out}.tmp"
  mv "${list_out}.tmp" "$list_out"
  echo "built: $mrs ($count rules)"
done

for src in custome-process-*.list; do
  [[ -f "$src" ]] || continue
  write_stripped_file "$src" "${PUBLISH}/${src}"
  count=0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*PROCESS-NAME(-WILDCARD|-REGEX)?, ]] || continue
    count=$((count + 1))
  done <"${PUBLISH}/${src}"
  echo "copied: $src ($count rules)"
done

echo "done. artifacts in $PUBLISH"

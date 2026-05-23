#!/usr/bin/env bash
# 从 Sukka Ruleset Git 镜像拉取 Clash 规则，domainset 转 .mrs；non_ip（含 KEYWORD/WILDCARD）仅发布 .list
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MIHOMO="${MIHOMO:-./mihomo}"
PUBLISH="${PUBLISH:-./publish}"
MANIFEST="${MANIFEST:-$ROOT/scripts/skk-rules.manifest}"
SKK_BASE="${SKK_BASE:-https://raw.githubusercontent.com/SukkaLab/ruleset.skk.moe/master/Clash}"

if [[ ! -x "$MIHOMO" ]]; then
  echo "error: mihomo 不可执行: $MIHOMO" >&2
  exit 1
fi

mkdir -p "$PUBLISH"

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

fetch_skk() {
  local remote_path="$1" dest="$2"
  local url="${SKK_BASE}/${remote_path}"
  echo "fetch: $url"
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$dest"
}

while IFS='|' read -r name remote_path kind || [[ -n "${name:-}" ]]; do
  [[ -z "${name:-}" ]] && continue
  [[ "$name" =~ ^# ]] && continue

  tmp="${PUBLISH}/.${name}.src.txt"
  fetch_skk "$remote_path" "$tmp"
  write_stripped_file "$tmp" "${tmp}.clean"
  mv "${tmp}.clean" "$tmp"

  case "$kind" in
    mrs)
      out="${PUBLISH}/${name}.mrs"
      count=0
      while IFS= read -r line; do
        line="${line%%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        count=$((count + 1))
      done <"$tmp"
      "$MIHOMO" convert-ruleset domain text "$tmp" "$out"
      echo "built: $out ($count domains)"
      ;;
    classical)
      out="${PUBLISH}/${name}.list"
      cp "$tmp" "$out"
      count=0
      while IFS= read -r line; do
        line="${line%%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        count=$((count + 1))
      done <"$out"
      echo "copied: $out ($count rules)"
      ;;
    *)
      echo "error: 未知类型 $kind（$name）" >&2
      exit 1
      ;;
  esac
  rm -f "$tmp"
done <"$MANIFEST"

echo "skk rules done."

#!/usr/bin/env bash
# run_limits.sh
# Orchestrates awx_prompt.sh launches across many products/limits.
# - Scope with -p:
#     -p tomcat      => family (all products under that family)
#     -p tomcat_ibm  => real product (only that product)
#     (no -p)        => all families
# - Multiple envs: -e DEV,STG,PRD
# - Throttle submits: -s seconds
# - Limit wrapper concurrency: -j N
#
# IMPORTANT:
# - This wrapper parses PRODUCTS and LIMITS directly from awx_prompt.sh (no stdout parsing).
# - NAS mounted with noexec is OK: always run as "bash run_limits.sh ...".
set -euo pipefail

# -------------------------
# Locate awx_prompt.sh (same dir as this wrapper)
# -------------------------
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/awx_prompt.sh"

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  bash run_limits.sh -r <EMEA|APAC|AMER> -e <DEV|STG|PRD[,DEV|STG|PRD...]> \
    [-p <scope>] [-u <update|create|install>] [-d <prod|dev>] [-t <true|false>] \
    [-s <secs>] [-j <max_parallel>]

Scope (-p):
  -p tomcat            => family "tomcat" (all its products + all their limits)
  -p tomcat_ibm        => real product (only that product + all its limits)
  (no -p)              => all families/products/limits

Region -> Instance Group (auto):
  EMEA -> MiddlewareFR
  APAC -> iv2apac
  AMER -> iv2amer
EOF
  exit 2
}

# -------------------------
# Defaults
# -------------------------
REGION=""
ENVS_CSV=""
SCOPE=""
UPDATE="update"
DATA_ENV="prod"
IS_ETS="false"
SLEEP_SECS="0"
MAX_PARALLEL="1"

FAMILIES_ALL=(apache sso iis jbosseap tomcat weblogic was)

# -------------------------
# Small helpers
# -------------------------
lc(){ printf '%s' "${1,,}"; }
uc(){ printf '%s' "${1^^}"; }
is_int(){ [[ "${1:-}" =~ ^[0-9]+$ ]]; }

valid_one_of_uc() {
  local v; v=$(uc "$1"); shift
  local opt
  for opt in "$@"; do
    [[ "$v" == "$opt" ]] && { printf '%s' "$v"; return 0; }
  done
  return 1
}

valid_one_of_lc() {
  local v; v=$(lc "$1"); shift
  local opt
  for opt in "$@"; do
    [[ "$v" == "$opt" ]] && { printf '%s' "$v"; return 0; }
  done
  return 1
}

derive_ig_from_region() {
  case "$1" in
    EMEA) printf '%s' "MiddlewareFR" ;;
    APAC) printf '%s' "iv2apac" ;;
    AMER) printf '%s' "iv2amer" ;;
    *) return 1 ;;
  esac
}

split_envs() {
  local csv="${1:-}"
  [[ -z "$csv" ]] && die "missing -e"

  local IFS=',' part
  for part in $csv; do
    part=$(uc "${part//[[:space:]]/}")
    part=$(valid_one_of_uc "$part" DEV STG PRD) || die "invalid env: $part"
    printf '%s\n' "$part"
  done | awk '!seen[$0]++'   # dedupe preserve order
}

# -------------------------
# Parse PRODUCTS/LIMITS directly from awx_prompt.sh
# -------------------------
products_for_family() {
  local fam="$1"
  awk -v fam="$fam" '
    BEGIN { inside=0 }
    # Start block: [fam]="
    $0 ~ "^[[:space:]]*\\[" fam "\\]=\"[[:space:]]*$" { inside=1; next }
    inside {
      # End block: line with only a quote
      if ($0 ~ /^[[:space:]]*"$/) { inside=0; exit }
      gsub(/\r/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 ~ /^[a-z0-9_]+$/) print $0
    }
  ' "$SCRIPT"
}

limits_for_product() {
  local prod="$1"
  awk -v prod="$prod" '
    function emit_tokens(s,   i,n,a) {
      gsub(/\r/, "", s)
      gsub(/\\/, "", s)
      gsub(/"/, "", s)
      n=split(s, a, /[[:space:]]+/)
      for (i=1; i<=n; i++) if (a[i] ~ /^[a-z0-9_]+$/) print a[i]
    }
    BEGIN { inside=0; buf="" }

    # Start: [prod]=".... (same line or multiline)
    $0 ~ "^[[:space:]]*\\[" prod "\\]=\"" {
      inside=1
      sub(/^[[:space:]]*\[[^]]+\]=""/, "", $0)
      buf=$0
      if (buf ~ /"$/) { emit_tokens(buf); exit }
      next
    }

    inside {
      # End multiline string: line with only a quote
      if ($0 ~ /^[[:space:]]*"$/) { emit_tokens(buf); exit }
      buf = buf " " $0
    }
  ' "$SCRIPT"
}

# Detect if a token is a family name
is_family() {
  local x; x=$(lc "$1")
  local f
  for f in "${FAMILIES_ALL[@]}"; do
    [[ "$x" == "$f" ]] && return 0
  done
  return 1
}

# Find owning family for a real product name
family_for_product() {
  local prod; prod=$(lc "$1")
  local f
  for f in "${FAMILIES_ALL[@]}"; do
    if products_for_family "$f" | grep -qx "$prod"; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

# Decide which families to traverse based on -p
resolve_families() {
  local p; p=$(lc "${1:-}")
  [[ -z "$p" ]] && { printf '%s\n' "${FAMILIES_ALL[@]}"; return 0; }

  if is_family "$p"; then
    printf '%s\n' "$p"
    return 0
  fi

  local fam
  fam=$(family_for_product "$p") || die "unknown scope for -p: $1"
  printf '%s\n' "$fam"
}

# -------------------------
# Args
# -------------------------
while (($#)); do
  case "$1" in
    -r|--region)    REGION="${2:-}"; shift 2 ;;
    -e|--envs)      ENVS_CSV="${2:-}"; shift 2 ;;
    -p|--product)   SCOPE="${2:-}"; shift 2 ;;
    -u|--update)    UPDATE="${2:-}"; shift 2 ;;
    -d|--data_env)  DATA_ENV="${2:-}"; shift 2 ;;
    -t|--is_ETS)    IS_ETS="${2:-}"; shift 2 ;;
    -s|--sleep)     SLEEP_SECS="${2:-}"; shift 2 ;;
    -j|--jobs)      MAX_PARALLEL="${2:-}"; shift 2 ;;
    -h|--help)      usage ;;
    *) usage ;;
  esac
done

[[ -f "$SCRIPT" ]] || die "awx_prompt.sh not found at: $SCRIPT"

REGION=$(valid_one_of_uc "$REGION" EMEA APAC AMER) || die "invalid region"
IG=$(derive_ig_from_region "$REGION") || die "cannot derive instance group"

UPDATE=$(valid_one_of_lc "$UPDATE" update create install) || die "invalid update"
DATA_ENV=$(valid_one_of_lc "$DATA_ENV" prod dev) || die "invalid data_env"
IS_ETS=$(valid_one_of_lc "$IS_ETS" true false) || die "invalid is_ETS"

is_int "$SLEEP_SECS" || die "sleep must be integer seconds"
is_int "$MAX_PARALLEL" || die "jobs (-j) must be integer"
(( MAX_PARALLEL >= 1 )) || die "jobs (-j) must be >= 1"

mapfile -t ENVS_LIST < <(split_envs "$ENVS_CSV")

scope_lc=$(lc "$SCOPE")

# -------------------------
# Build queue (prod|limit|env)
# -------------------------
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

for fam in $(resolve_families "$scope_lc"); do
  mapfile -t PRODS < <(products_for_family "$fam")

  # If -p is a real product (not a family), force PRODS to that single product
  if [[ -n "$scope_lc" && "$scope_lc" != "$fam" ]]; then
    PRODS=("$scope_lc")
  fi

  for prod in "${PRODS[@]}"; do
    mapfile -t LIMITS < <(limits_for_product "$prod")

    for lim in "${LIMITS[@]}"; do
      for env in "${ENVS_LIST[@]}"; do
        printf '%s|%s|%s\n' "$prod" "$lim" "$env" >> "$tmp"
      done
    done
  done
done

# Validate queue
total=$(wc -l < "$tmp" | tr -d ' ')
if [[ "$total" -eq 0 ]]; then
  die "Queue is empty. PRODUCTS/LIMITS parsing returned nothing."
fi

# -------------------------
# Launch one item
# -------------------------
run_one() {
  local prod="$1" lim="$2" env="$3"

  # Always run via bash (NAS noexec safe)
  bash "$SCRIPT" \
    -r "$REGION" -e "$env" -p "$prod" -l "$lim" \
    -u "$UPDATE" -g "$IG" -d "$DATA_ENV" -t "$IS_ETS"
}

# -------------------------
# Execute with throttling + limited parallelism
# -------------------------
while IFS='|' read -r prod lim env; do
  run_one "$prod" "$lim" "$env" &

  while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do
    wait -n
  done

  if (( SLEEP_SECS > 0 )); then
    sleep "$SLEEP_SECS"
  fi
done < "$tmp"

wait

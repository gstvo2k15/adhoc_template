#!/usr/bin/env bash
# run_limits.sh
# Orchestrates executions of awx_prompt.sh:
# - Can run EVERYTHING (all families/products/limits) or narrow scope with -p
# - Supports multiple environments: -e DEV,STG,PRD
# - Throttles submits with -s (sleep between submits) and limits concurrency with -j
# - For real parallelism you MUST have awx_prompt.sh support --no-monitor
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/awx_prompt.sh"

usage() {
  cat <<'EOF'
Usage:
  bash run_limits.sh -r <EMEA|APAC|AMER> -e <DEV|STG|PRD[,DEV|STG|PRD...]> \
    [-p <scope>] [-u <update|create|install>] [-d <prod|dev>] [-t <true|false>] \
    [-s <secs>] [-j <max_parallel>] [--no-monitor]

Scope (-p):
  -p tomcat            => family "tomcat" (all its real products + all their limits)
  -p tomcat_ibm        => real product (only that product + all its limits)
  (no -p)              => all families/products/limits

Region -> Instance Group (auto):
  EMEA -> MiddlewareFR
  APAC -> iv2apac
  AMER -> iv2amer

e.g.:
# tomcat family, two envs, 3 parallel submits, 45s between submits (recommended with --no-monitor)
./run_limits.sh -r EMEA -e DEV,STG -p tomcat -u update -d prod -t false -j 3 -s 45 --no-monitor

# single real product
./run_limits.sh -r EMEA -e DEV -p tomcat_ibm -u update -d prod -t false -j 2 -s 60 --no-monitor

# everything, one env
./run_limits.sh -r APAC -e PRD -u install -d prod -t true -j 2 -s 60 --no-monitor

Notes:
  --no-monitor is passed to awx_prompt.sh. It requires awx_prompt.sh to support it.
  -j controls wrapper-level parallel processes. If awx_prompt.sh uses --monitor, it will still block.
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
NO_MONITOR="no"

FAMILIES_ALL=(apache sso iis jbosseap tomcat weblogic was)

# -------------------------
# Helpers
# -------------------------
lc(){ printf '%s' "${1,,}"; }
uc(){ printf '%s' "${1^^}"; }

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

is_int(){ [[ "${1:-}" =~ ^[0-9]+$ ]]; }

valid_one_of_uc() {
  local v
  v=$(uc "$1")
  shift
  local opt
  for opt in "$@"; do
    [[ "$v" == "$opt" ]] && { printf '%s' "$v"; return 0; }
  done
  return 1
}

valid_one_of_lc() {
  local v
  v=$(lc "$1")
  shift
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

extract_products_from_family_output() {
  awk '
    /^List of all products related to / {inside=1; next}
    inside && $1 ~ /^[a-z0-9_]+$/ { print $1 }
    inside && NF==0 { exit }
  '
}

extract_limits_from_product_output() {
  awk '
    { for (i=1; i<=NF; i++) if ($i ~ /^[a-z0-9_]+_[a-z0-9_]+$/) { print $i; break } }
  '
}

# Decide which families to traverse based on -p:
# - no -p => all families
# - -p == family => that family
# - -p == real product => detect its owning family and return it
resolve_families() {
  local p="${1:-}"
  p=$(lc "$p")

  [[ -z "$p" ]] && { printf '%s\n' "${FAMILIES_ALL[@]}"; return 0; }

  local f
  for f in "${FAMILIES_ALL[@]}"; do
    [[ "$p" == "$f" ]] && { printf '%s\n' "$f"; return 0; }
  done

  # real product: search inside each family listing
  for f in "${FAMILIES_ALL[@]}"; do
    if bash "$SCRIPT" "$f" | grep -qx "  $p"; then
      printf '%s\n' "$f"
      return 0
    fi
  done

  die "unknown scope for -p: $1"
}

# Validate env CSV and emit envs (one per line, uppercase)
split_envs() {
  local csv="${1:-}"
  [[ -z "$csv" ]] && die "missing -e"

  local IFS=',' part
  for part in $csv; do
    part=$(uc "${part//[[:space:]]/}")
    part=$(valid_one_of_uc "$part" DEV STG PRD) || die "invalid env: $part"
    printf '%s\n' "$part"
  done | awk '!seen[$0]++'  # dedupe preserving order
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
    --no-monitor)   NO_MONITOR="yes"; shift ;;
    -h|--help)      usage ;;
    *) usage ;;
  esac
done

REGION=$(valid_one_of_uc "$REGION" EMEA APAC AMER) || die "invalid region"
IG=$(derive_ig_from_region "$REGION") || die "cannot derive instance group"

UPDATE=$(valid_one_of_lc "$UPDATE" update create install) || die "invalid update"
DATA_ENV=$(valid_one_of_lc "$DATA_ENV" prod dev) || die "invalid data_env"
IS_ETS=$(valid_one_of_lc "$IS_ETS" true false) || die "invalid is_ETS"

is_int "$SLEEP_SECS" || die "sleep must be integer seconds"
is_int "$MAX_PARALLEL" || die "jobs (-j) must be integer"
(( MAX_PARALLEL >= 1 )) || die "jobs (-j) must be >= 1"

mapfile -t ENVS_LIST < <(split_envs "$ENVS_CSV")

# -------------------------
# Build queue (prod|limit|env)
# -------------------------
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

scope_lc=$(lc "$SCOPE")

for fam in $(resolve_families "$scope_lc"); do
  mapfile -t PRODS < <(bash "$SCRIPT" "$fam" | extract_products_from_family_output)

  # If -p is a real product (not a family), force PRODS to that single product
  if [[ -n "$scope_lc" && "$scope_lc" != "$fam" ]]; then
    PRODS=("$scope_lc")
  fi

  for prod in "${PRODS[@]}"; do
    mapfile -t LIMITS < <(bash "$SCRIPT" "$prod" | extract_limits_from_product_output)

    for lim in "${LIMITS[@]}"; do
      for env in "${ENVS_LIST[@]}"; do
        printf '%s|%s|%s\n' "$prod" "$lim" "$env" >> "$tmp"
      done
    done
  done
done

# -------------------------
# Launch function (one item)
# -------------------------
run_one() {
  local prod="$1" lim="$2" env="$3"

  if [[ "$NO_MONITOR" == "yes" ]]; then
    bash "$SCRIPT" --no-monitor \
      -r "$REGION" -e "$env" -p "$prod" -l "$lim" \
      -u "$UPDATE" -g "$IG" -d "$DATA_ENV" -t "$IS_ETS"
  else
    bash "$SCRIPT" \
      -r "$REGION" -e "$env" -p "$prod" -l "$lim" \
      -u "$UPDATE" -g "$IG" -d "$DATA_ENV" -t "$IS_ETS"
  fi
}

export -f run_one
export SCRIPT REGION UPDATE IG DATA_ENV IS_ETS NO_MONITOR

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


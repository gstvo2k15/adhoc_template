#!/usr/bin/env bash
# run_all_limits.sh
set -euo pipefail

SCRIPT="./awx_prompt.sh"

usage() {
  cat <<'EOF'
Usage:
  run_all_limits.sh -r <EMEA|APAC|AMER> -e <DEV|STG|PRD> [-u <update|create|install>] [-d <prod|dev>] [-t <true|false>]
e.g:
./run_all_limits.sh -r EMEA -e DEV -u update -d prod -t false
./run_all_limits.sh -r APAC -e STG -u update -d prod -t false
./run_all_limits.sh -r AMER -e PRD -u install -d prod -t true

Notes:
  - Instance group is auto-derived from region:
      EMEA -> MiddlewareFR
      APAC -> iv2apac
      AMER -> iv2amer
  - Runs awx_prompt.sh for every product+limit (all families).
EOF
  exit 2
}

# Defaults
REGION=""
ENVS=""
UPDATE="update"
DATA_ENV="prod"
IS_ETS="false"
IG=""

FAMILIES=(apache sso iis jbosseap tomcat weblogic was)

lc(){ printf '%s' "${1,,}"; }

valid_one_of() {
  local val="$1"; shift
  local v="${val^^}"
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
    /^List of all products related to / {in=1; next}
    in && /^[[:space:]]{2}[a-z0-9_]+[[:space:]]*$/ {gsub(/^[ \t]+|[ \t]+$/,""); print}
    in && /^$/ {exit}
  '
}

extract_limits_from_product_output() {
  awk '/^  • /{sub(/^  • /,""); print}'
}

# Args
while (($#)); do
  case "$1" in
    -r|--region)   REGION="${2:-}"; shift 2 ;;
    -e|--envs)     ENVS="${2:-}"; shift 2 ;;
    -u|--update)   UPDATE="${2:-}"; shift 2 ;;
    -d|--data_env) DATA_ENV="${2:-}"; shift 2 ;;
    -t|--is_ETS)   IS_ETS="${2:-}"; shift 2 ;;
    -h|--help)     usage ;;
    *) usage ;;
  esac
done

# Validate + normalize
REGION=$(valid_one_of "$REGION" EMEA APAC AMER) || { printf 'ERROR: invalid region\n' >&2; exit 1; }
ENVS=$(valid_one_of "$ENVS" DEV STG PRD)       || { printf 'ERROR: invalid envs\n' >&2; exit 1; }

UPDATE=$(lc "$UPDATE")
case "$UPDATE" in update|create|install) : ;; *) printf 'ERROR: invalid update\n' >&2; exit 1;; esac

DATA_ENV=$(lc "$DATA_ENV")
case "$DATA_ENV" in prod|dev) : ;; *) printf 'ERROR: invalid data_env\n' >&2; exit 1;; esac

IS_ETS=$(lc "$IS_ETS")
case "$IS_ETS" in true|false) : ;; *) printf 'ERROR: invalid is_ETS\n' >&2; exit 1;; esac

IG=$(derive_ig_from_region "$REGION") || { printf 'ERROR: cannot derive instance group\n' >&2; exit 1; }

# Run
for fam in "${FAMILIES[@]}"; do
  mapfile -t PRODS < <(bash "$SCRIPT" "$fam" | extract_products_from_family_output)

  for prod in "${PRODS[@]}"; do
    mapfile -t LIMITS < <(bash "$SCRIPT" "$prod" | extract_limits_from_product_output)

    for lim in "${LIMITS[@]}"; do
      bash "$SCRIPT" -r "$REGION" -e "$ENVS" -p "$prod" -l "$lim" \
        -u "$UPDATE" -g "$IG" -d "$DATA_ENV" -t "$IS_ETS"
    done
  done
done

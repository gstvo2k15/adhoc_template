#!/usr/bin/env bash
#====================================================================
# awx_prompt.sh - Build the Awx launch command
#
# Example (all options on one line):
# ./awx_prompt.sh -r EMEA -e DEV -p CSA_IMPORTED_jbosseap \
#     -l csa_imported_jbosseap_emea_dev_core \
#     -u update -g MiddlewareFR -d prod -t false
#
# If any option is omitted the script will ask for it interactively.
# Additional modes:
# ./awx_prompt.sh --help              -> help + product table
# ./awx_prompt.sh --help <product>    -> help (no table) + limits of <product>
# ./awx_prompt.sh <product>           -> list limits for product
# ./awx_prompt.sh <product> <limit>   -> validate that <limit> belongs to product
#====================================================================
set -euo pipefail

source /apps/patching/.token-plat

LOG_FOLD=/apps/patching/plat/logs
logfile=$LOG_FOLD/run-patch-linux-$(date +%Y-%d-%m_%Hh%M).log

#--------------------------------------------------------------------
# 1.- Product -> limits dictionary
#--------------------------------------------------------------------
declare -A PRODUCTS=(
    [apache]="
    apache
    apache_dmzi
    apache_dmzi_apac
    apache_dmzi_emea
    apache_dmzi_amer
    apache_wsgi
    csa_imported_apache_dmzi
    dpi_upgraded_apache
    "

    [sso]="
    sso_as_a_service
    dpi_upgraded_sso_as_a_service
    sso_as_a_service_ibm_dmzr
    sso_as_a_service_ibm_vdc
    "

    [iis]="
    iis_all_windows_version
    iis_dmzi
    iis_dmzi_apac
    iis_dmzi_amer
    iis_ets
    iis_vpc
    iis_mzr
    dpi_upgraded_iis_all_windows_version_vmware
    "

    [jbosseap]="
    jbosseap
    csa_imported_jbosseap
    "

    [tomcat]="
    jboss_ews
    dpi_upgraded_jboss_ews
    dpi_upgraded_tomcat
    tomcat
    tomcat_ibm
    tomcat_ibmcloud_vpc
    "

    [weblogic]="
    weblogic
    weblogic_windows
    "

    [was]="
    websphere_base
    wasbase_admin_vmware
    dpi_upgraded_wasbase_admin_vmware
    wasnd
    "
)

declare -A LIMITS=(
    [apache]="apache_emea_dev_core apache_emea_stg_core apache_emea_prd_core \
    apache_apac_dev_core apache_apac_stg_core apache_apac_prd_core \
    apache_amer_dev_core apache_amer_stg_core apache_amer_prd_core \
    apache_emea_prd_ets apache_amer_prd_ets"

    [sso_as_a_service]="sso_as_a_service_emea_dev_core sso_as_a_service_emea_stg_core sso_as_a_service_emea_prd_core \
    sso_as_a_service_apac_dev_core sso_as_a_service_apac_stg_core sso_as_a_service_apac_prd_core \
    sso_as_a_service_amer_dev_core sso_as_a_service_amer_stg_core sso_as_a_service_amer_prd_core \
    sso_as_a_service_ibm_dmzr_emea_dev_mzr sso_as_a_service_ibm_dmzr_emea_stg_mzr sso_as_a_service_ibm_dmzr_emea_prd_mzr \
    sso_as_a_service_ibm_vdc_amer_dev_intranet sso_as_a_service_ibm_vdc_amer_stg_intranet sso_as_a_service_ibm_vdc_amer_prd_intranet"

    [dpi_upgraded_sso_as_a_service]="dpi_upgraded_sso_as_a_service_emea_dev_core dpi_upgraded_sso_as_a_service_emea_stg_core dpi_upgraded_sso_as_a_service_emea_prd_core \
    dpi_upgraded_sso_as_a_service_apac_dev_core dpi_upgraded_sso_as_a_service_apac_stg_core dpi_upgraded_sso_as_a_service_apac_prd_core \
    dpi_upgraded_sso_as_a_service_amer_dev_core dpi_upgraded_sso_as_a_service_amer_stg_core dpi_upgraded_sso_as_a_service_amer_prd_core"

    [sso_as_a_service_ibm_dmzr]="sso_as_a_service_ibm_dmzr_emea_dev_mzr sso_as_a_service_ibm_dmzr_emea_stg_mzr sso_as_a_service_ibm_dmzr_emea_prd_mzr"

    [sso_as_a_service_ibm_vdc]="sso_as_a_service_ibm_vdc_amer_dev_intranet sso_as_a_service_ibm_vdc_amer_stg_intranet sso_as_a_service_ibm_vdc_amer_prd_intranet"

    [apache_dmzi]="apache_dmzi_emea_dev_dmzi apache_dmzi_emea_stg_dmzi apache_dmzi_emea_prd_dmzi \
    apache_dmzi_apac_dev_dmzi apache_dmzi_apac_stg_dmzi apache_dmzi_apac_prd_dmzi \
    apache_dmzi_amer_stg_dmzi apache_dmzi_amer_prd_dmzi"

    [apache_dmzi_apac]="apache_dmzi_apac_apac_dev_dmzi apache_dmzi_apac_apac_stg_dmzi \
    apache_dmzi_apac_apac_prd_dmzi"

    [apache_dmzi_emea]="apache_dmzi_emea_emea_dev_dmzi apache_dmzi_emea_emea_stg_dmzi \
    apache_dmzi_emea_emea_prd_dmzi"

    [apache_dmzi_amer]="apache_dmzi_amer_amer_stg_dmzi apache_dmzi_amer_amer_prd_dmzi"

    [apache_wsgi]="apache_wsgi_emea_dev_core apache_wsgi_emea_stg_core apache_wsgi_emea_prd_core"

    [csa_imported_apache_dmzi]="csa_imported_apache_dmzi_emea_emea_stg_dmzi \
    csa_imported_apache_dmzi_emea_emea_prd_dmzi"

    [dpi_upgraded_apache]="dpi_upgraded_apache_emea_dev_core dpi_upgraded_apache_emea_stg_core \
    dpi_upgraded_apache_emea_prd_core dpi_upgraded_apache_apac_dev_core \
    dpi_upgraded_apache_apac_stg_core dpi_upgraded_apache_apac_prd_core \
    dpi_upgraded_apache_amer_dev_core dpi_upgraded_apache_amer_stg_core \
    dpi_upgraded_apache_amer_prd_core dpi_upgraded_apache_emea_prd_ets"

    [iis_all_windows_version]="iis_all_windows_version_emea_dev_core iis_all_windows_version_emea_stg_core \
    iis_all_windows_version_emea_prd_core iis_all_windows_version_apac_dev_core \
    iis_all_windows_version_apac_stg_core iis_all_windows_version_apac_prd_core \
    iis_all_windows_version_amer_dev_core iis_all_windows_version_amer_stg_core \
    iis_all_windows_version_amer_prd_core iis_all_windows_version_amer_prd_ets"

    [iis_dmzi]="iis_dmzi_emea_dev_dmzi iis_dmzi_emea_stg_dmzi iis_dmzi_emea_prd_dmzi \
    iis_dmzi_amer_dev_dmzi iis_dmzi_amer_stg_dmzi iis_dmzi_amer_prd_dmzi"

    [iis_dmzi_apac]="iis_dmzi_apac_apac_dev_dmzi iis_dmzi_apac_apac_prd_dmzi"

    [iis_dmzi_amer]="iis_dmzi_amer_amer_stg_dmzi"

    [iis_ets]="iis_ets_emea_prd_ets"

    [iis_vpc]="iis_vpc_emea_dev_mzr iis_vpc_emea_stg_mzr iis_vpc_emea_prd_mzr"

    [iis_mzr]="iis_mzr_amer_dev_mzr iis_mzr_amer_stg_mzr iis_mzr_amer_prd_mzr"

    [dpi_upgraded_iis_all_windows_version_vmware]="dpi_upgraded_iis_all_windows_version_vmware_emea_dev_core \
    dpi_upgraded_iis_all_windows_version_vmware_emea_stg_core \
    dpi_upgraded_iis_all_windows_version_vmware_emea_prd_core \
    dpi_upgraded_iis_all_windows_version_vmware_apac_dev_core \
    dpi_upgraded_iis_all_windows_version_vmware_apac_stg_core \
    dpi_upgraded_iis_all_windows_version_vmware_apac_prd_core \
    dpi_upgraded_iis_all_windows_version_vmware_amer_dev_core \
    dpi_upgraded_iis_all_windows_version_vmware_amer_stg_core \
    dpi_upgraded_iis_all_windows_version_vmware_amer_prd_core"

    [jbosseap]="jbosseap_emea_dev_core jbosseap_emea_stg_core jbosseap_emea_prd_core \
    jbosseap_apac_dev_core jbosseap_apac_stg_core jbosseap_apac_prd_core \
    jbosseap_amer_dev_core jbosseap_amer_stg_core jbosseap_amer_prd_core"

    [csa_imported_jbosseap]="csa_imported_jbosseap_emea_dev_core csa_imported_jbosseap_emea_stg_core \
    csa_imported_jbosseap_emea_prd_core"

    [jboss_ews]="jboss_ews_emea_dev_core jboss_ews_emea_stg_core jboss_ews_emea_prd_core \
    jboss_ews_apac_dev_core jboss_ews_apac_stg_core jboss_ews_apac_prd_core \
    jboss_ews_amer_dev_core jboss_ews_amer_stg_core jboss_ews_amer_prd_core"

    [dpi_upgraded_jboss_ews]="dpi_upgraded_jboss_ews_emea_dev_core dpi_upgraded_jboss_ews_emea_stg_core \
    dpi_upgraded_jboss_ews_emea_prd_core dpi_upgraded_jboss_ews_apac_dev_core \
    dpi_upgraded_jboss_ews_apac_stg_core dpi_upgraded_jboss_ews_apac_prd_core \
    dpi_upgraded_jboss_ews_amer_dev_core dpi_upgraded_jboss_ews_amer_stg_core \
    dpi_upgraded_jboss_ews_amer_prd_core"

    [dpi_upgraded_tomcat]="dpi_upgraded_tomcat_emea_dev_core dpi_upgraded_tomcat_emea_stg_core \
    dpi_upgraded_tomcat_emea_prd_core dpi_upgraded_tomcat_emea_prd_ets \
    dpi_upgraded_tomcat_apac_dev_core dpi_upgraded_tomcat_apac_stg_core \
    dpi_upgraded_tomcat_apac_prd_core dpi_upgraded_tomcat_amer_dev_core \
    dpi_upgraded_tomcat_amer_stg_core dpi_upgraded_tomcat_amer_prd_core"

    [tomcat]="tomcat_emea_dev_core tomcat_emea_stg_core tomcat_emea_prd_core \
    tomcat_apac_dev_core tomcat_apac_stg_core tomcat_apac_prd_core \
    tomcat_amer_dev_core tomcat_amer_prd_core tomcat_emea_prd_ets \
    tomcat_amer_prd_ets"

    [tomcat_ibm]="tomcat_ibm_amer_dev_mzr tomcat_ibm_amer_stg_mzr tomcat_ibm_amer_prd_mzr"

    [tomcat_ibmcloud_vpc]="tomcat_ibmcloud_vpc_emea_dev_mzr tomcat_ibmcloud_vpc_emea_stg_mzr \
    tomcat_ibmcloud_vpc_emea_prd_mzr"

    [weblogic]="weblogic_emea_dev_core weblogic_emea_stg_core weblogic_emea_prd_core \
    weblogic_apac_dev_core weblogic_apac_stg_core weblogic_apac_prd_core \
    weblogic_amer_dev_core weblogic_amer_prd_core"

    [weblogic_windows]="weblogic_windows_emea_dev_core weblogic_windows_emea_stg_core weblogic_windows_emea_prd_core"

    [websphere_base]="websphere_base_emea_dev_core websphere_base_emea_stg_core websphere_base_emea_prd_core \
    websphere_base_apac_dev_core websphere_base_apac_stg_core"

    [wasbase_admin_vmware]="wasbase_admin_vmware_emea_dev_core wasbase_admin_vmware_emea_stg_core \
    wasbase_admin_vmware_emea_prd_core wasbase_admin_vmware_apac_dev_core \
    wasbase_admin_vmware_apac_stg_core wasbase_admin_vmware_apac_prd_core \
    wasbase_admin_vmware_amer_dev_core wasbase_admin_vmware_amer_stg_core \
    wasbase_admin_vmware_amer_prd_core"

    [dpi_upgraded_wasbase_admin_vmware]="dpi_upgraded_wasbase_admin_vmware_emea_dev_core \
    dpi_upgraded_wasbase_admin_vmware_emea_stg_core \
    dpi_upgraded_wasbase_admin_vmware_emea_prd_core \
    dpi_upgraded_wasbase_admin_vmware_apac_dev_core \
    dpi_upgraded_wasbase_admin_vmware_apac_stg_core \
    dpi_upgraded_wasbase_admin_vmware_apac_prd_core \
    dpi_upgraded_wasbase_admin_vmware_amer_dev_core \
    dpi_upgraded_wasbase_admin_vmware_amer_stg_core \
    dpi_upgraded_wasbase_admin_vmware_amer_prd_core"

    [wasnd]="wasnd_emea_dev_core wasnd_apac_dev_core wasnd_apac_stg_core wasnd_apac_prd_core"
)

# -------------------------------------------------------------------
# Allowed values for the generic extra-vars
# -------------------------------------------------------------------
REGIONS=(EMEA APAC AMER)
ENVS=(DEV STG PRD)
UPDATES=(update create install)
INSTANCE_GROUPS=(none iv2apac iv2amer MiddlewareFR)
IS_ETS_VALUES=(true false)

# -------------------------------------------------------------------
# Helpers base
# -------------------------------------------------------------------
lc() { printf '%s' "${1,,}"; }

list_products_for_family() {
    local fam
    fam=$(lc "$1")

    local raw="${PRODUCTS[$fam]-}"
    [[ -z $raw ]] && { printf 'ERROR: Unknown family "%s".\n' "$fam" >&2; exit 2; }

    printf '%s\n' "$raw" \
        | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
}

show_family() {
    local family
    family=$(lc "$1")

    mapfile -t sorted < <(list_products_for_family "$family" | sort)

    printf 'List of all products related to %s (total %d):\n' "$family" "${#sorted[@]}"
    local p
    for p in "${sorted[@]}"; do
        printf '  %s\n' "$p"
    done
    printf '\n'

    for p in "${sorted[@]}"; do
        list_limits "$p"
    done
}


# -------------------------------------------------------------------
# Helper: print usage (optional argument suppresses product table)
# -------------------------------------------------------------------
usage() {
    local show_table=${1:-yes}
    cat <<'EOF'
awx_prompt.sh - Build the AWX launch command

Usage:
  awx_prompt.sh --help
    Show this help.

  awx_prompt.sh --help <product>
    Show help (no product table) and list limits for <product>.

  awx_prompt.sh <product>
    List limits for <product>.

  awx_prompt.sh <product> <limit>
    Validate that <limit> belongs to <product>.

  awx_prompt.sh [options]

Options (both long and short forms):
  -r, --region <REGION>      EMEA | APAC | AMER
  -e, --env <ENV>            DEV | STG | PRD
  -p, --product <PRODUCT>    apache|sso|tomcat|jbosseap|iis|weblogic|was
  -l, --limit <LIMIT>        (optional, must belong to product)
  -u, --update <UPDATE>      update | create | install
  -d, --data_env <DATA ENV>   prod | dev
  -t, --is_ETS <true|false>   false | true

If any option is omitted the script will ask for it interactively.
All arguments are case-insensitive.
EOF

    if [[ $show_table == yes ]]; then
        printf '\nProducts (alphabetical):\n'
        printf '  %-30s %s\n' 'Product' 'Limits'
        printf '  %-30s %s\n' '------' '------'
        while IFS= read -r prod; do
            cnt=$(printf '%s\n' "${LIMITS[$prod]}" | wc -w)
            printf '  %-30s %s\n' "$prod" "$cnt"
        done < <(printf '%s\n' "${!LIMITS[@]}" | sort)
        printf '\n'
    fi
}

# -------------------------------------------------------------------
# Helper: list limits for a product (now ONE LIMIT PER LINE)
# -------------------------------------------------------------------
list_limits() {
    local prod
    prod=$(lc "$1")

    local list="${LIMITS[$prod]-}"
    if [[ -z $list ]]; then
        printf 'ERROR: Unknown product "%s".\n' "$prod" >&2
        exit 2
    fi

    local cnt
    cnt=$(printf '%s\n' "$list" | wc -w | tr -d ' ')
    printf '\nLimits for product "%s" (total %s):\n' "$prod" "$cnt"

    local IFS=' '
    local lim
    # ---- iterate over the space-separated list and print each item ----
    for lim in $list; do
        printf '  • %s\n' "$lim"
    done
}

# -------------------------------------------------------------------
# Helper: validate a limit against a product
# -------------------------------------------------------------------
validate_limit() {
    local prod
    prod=$(lc "$1")
    local lim
    lim=$(lc "$2")

    local list=${LIMITS[$prod]-}
    if [[ -z $list ]]; then
        printf 'ERROR: Unknown product "%s".\n' "$prod" >&2
        exit 2
    fi

    local IFS=' '
    local l
    for l in $list; do
        if [[ "$l" == "$lim" ]]; then
            printf 'Limit "%s" is valid for product "%s".\n' "$lim" "$prod"
            exit 0
        fi
    done
    printf 'ERROR: Limit "%s" does NOT belong to product "%s".\n' "$lim" "$prod" >&2
    exit 1
}

# -------------------------------------------------------------------
# Helper: case-insensitive validation against a whitelist
# -------------------------------------------------------------------
valid_value() {
    local val=$1; shift
    local -a allowed=("$@")
    local lc=${val,,}

    local opt
    for opt in "${allowed[@]}"; do
        if [[ "$lc" == "${opt,,}" ]]; then
            printf '%s' "$opt"
            return 0
        fi
    done
    return 1
}

# -------------------------------------------------------------------
# Prompt helper (used when a value is missing)
# -------------------------------------------------------------------
prompt() {
    local msg=$1
    local reply
    read -rp "$msg: " reply
    printf '%s' "$reply"
}

# -------------------------------------------------------------------
# 1.- Parse arguments (long and short forms)
# -------------------------------------------------------------------
declare region='' envs='' product='' limit='' update='' instance_group='' data_env='' is_ETS=''

while (($#)); do
    case "$1" in
        -r|--region)            region=$2; shift 2 ;;
        -e|--envs)              envs=$2; shift 2 ;;
        -p|--product)           product=$2; shift 2 ;;
        -l|--limit)             limit=$2; shift 2 ;;
        -u|--update)            update=$2; shift 2 ;;
        -g|--instance_group)    instance_group=$2; shift 2 ;;
        -d|--data_env)          data_env=$2; shift 2 ;;
        -t|--is_ETS)            is_ETS=$2; shift 2 ;;
        -h|--help) 
            # ----------------------------------------------------------
            # --help           -> full help + product table
            # --help <product> -> short help + products that start with <product>
            #                     and their limits (one per line)
            # ----------------------------------------------------------
            if [[ $# -gt 1 ]]; then
                usage no_table
                printf '\n'

                prefix=${2,,}
                usage no_table
                printf '\n'
                show_family "$2"
                exit 0
            else
                usage
                exit 0
            fi
            ;;
        *) break ;;
    esac
done

# -------------------------------------------------------------------
# 2.- Special cases: list-limits / validate-limit (no "builder" options)
# -------------------------------------------------------------------
arg1=$(lc "${1-}")

if [[ $# -eq 1 && -n ${PRODUCTS[$arg1]+_} ]]; then
    show_family "$arg1"
    exit 0
fi

if [[ $# -eq 1 && -n ${LIMITS[$arg1]+_} ]]; then
    list_limits "$arg1"
    exit 0
fi

if [[ $# -eq 2 && -n ${LIMITS[$arg1]+_} ]]; then
    validate_limit "$1" "$2"
    exit $?
fi

# -------------------------------------------------------------------
# 3.- Interactive filling - ask for any missing option
# -------------------------------------------------------------------
[[ -z $region  ]] && region=$(prompt "Region (EMEA/APAC/AMER)")
[[ -z $envs    ]] && envs=$(prompt "Env (DEV/STG/PRD)")
[[ -z $product ]] && product=$(prompt "Product")

region=$(valid_value "$region" "${REGIONS[@]}") || { printf 'Invalid region.\n' >&2; exit 1; }
envs=$(valid_value "$envs" "${ENVS[@]}")       || { printf 'Invalid env.\n' >&2; exit 1; }

product=$(lc "$product")

# Show limits for the chosen product (if any) and let the user pick one
if [[ -z $limit && -n ${LIMITS[$product]+_} ]]; then
    printf 'Available limits for %s:\n' "$product"
    list_limits "$product"
    printf '\n'
    limit=$(prompt "Choose a limit (or press ENTER to skip)")
fi

[[ -z $update         ]] && update=$(prompt "Update (update/create/install)")
[[ -z $instance_group ]] && instance_group=$(prompt "Instance group (none/iv2apac/iv2amer)")

if [[ -z $instance_group || "${instance_group,,}" == "none" ]]; then
    instance_group="MiddlewareFR"
fi

[[ -z $data_env ]] && data_env=$(prompt "Data environment (e.g. prod)")
[[ -z $is_ETS   ]] && is_ETS=$(prompt "Is ETS? (true/false)")

# -------------------------------------------------------------------
# 4.- Validate the collected values
# -------------------------------------------------------------------
region=$(valid_value "$region" "${REGIONS[@]}")            || { printf 'Invalid region.\n' >&2; exit 1; }
envs=$(valid_value "$envs" "${ENVS[@]}")                   || { printf 'Invalid env.\n' >&2; exit 1; }
update=$(valid_value "$update" "${UPDATES[@]}")            || { printf 'Invalid update.\n' >&2; exit 1; }
instance_group=$(valid_value "$instance_group" "${INSTANCE_GROUPS[@]}") \
    || { printf 'Invalid instance group.\n' >&2; exit 1; }
is_ETS=$(valid_value "$is_ETS" "${IS_ETS_VALUES[@]}")      || { printf 'Invalid is_ETS flag.\n' >&2; exit 1; }

product_raw=$product
product_lc=$(lc "$product_raw")

# Validate parsed product
if [[ -z ${LIMITS[$product]+_} ]]; then
    printf 'ERROR: Unknown product: "%s".\n' "$product_raw" >&2
    exit 2
fi

# If a limit was provided, be sure it belongs to the product
if [[ -n $limit ]]; then
    limit=$(lc "$limit")
    matched_limit=''
    IFS=' '

    for l in ${LIMITS[$product_lc]}; do
        [[ $l == "$limit" ]] && matched_limit=$l && break
    done

    if [[ -z $matched_limit ]]; then
        printf 'ERROR: Limit "%s" does not belong to product "%s".\n' "$limit" "$product_raw" >&2
        exit 1
    fi

    limit=$matched_limit
fi

declare -A PRODUCT_CANONICAL=(
    [csa_imported_jbosseap]=CSA_IMPORTED_jbosseap
    [jbosseap]=jbosseap
    [apache]=apache
    [sso]=sso_as_a_service
    [iis]=iis_all_windows_version
    [tomcat]=tomcat
    [weblogic]=weblogic
    [was]=websphere_base
)

product_for_json=${PRODUCT_CANONICAL[$product_lc]:-$product_lc}

# -------------------------------------------------------------------
# 5.- Build and display the final AWX command
# -------------------------------------------------------------------
json=$(cat <<EOF
{
  "region":"$region",
  "envs":"$envs",
  "product":"$product_for_json",
  "limit":"$limit",
  "update":"$update",
  "instance_group":"$instance_group",
  "data_env":"$data_env",
  "is_ETS":"$is_ETS"
}
EOF
)

# Use `printf --` so that a leading "-" or "--" is never taken as an option.
printf -- '\n--- Debug AWX parsed command -------------------------------------------\n'
printf -- 'awx -k job_templates launch '\''Elastic_inventory_TESTING'\'' \\\n'
printf -- '  --extra_vars %q \\\n' "$json"
printf -- '  --verbosity 0 \n'
printf -- '-----------------------------------------------------------------------\n'

printf -- '\n--- Real execution in progress... --------------------------------------\n'
# Run the command (the %q quoting makes sure the JSON stays a single argument)
awx -k job_templates launch 'Elastic_inventory_TESTING' \
  --extra_vars "$json" \
  --verbosity 0

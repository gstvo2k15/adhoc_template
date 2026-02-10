#!/usr/bin/env bash
set -euo pipefail
set +H

HOST="${HOST:-https://pamela-mdw.cib.echonet}"
DISCOVER_URL="${DISCOVER_URL:-}"

[[ -z "$DISCOVER_URL" ]] && echo "DISCOVER_URL not set" && exit 1

COOKIE_JAR=$(mktemp)

read -r -p "User: " USER
read -r -s -p "Password: " PASS
echo

curl -sk -c "$COOKIE_JAR" -u "$USER:$PASS" "$HOST/_dashboards/auth/login" >/dev/null 2>&1 || true

JOB=$(curl -sk -b "$COOKIE_JAR" \
 -H "osd-xsrf: true" \
 -H "Content-Type: application/json" \
 -XPOST "$HOST/_dashboards/api/reporting/generate/csv" \
 -d "{\"url\":\"$DISCOVER_URL\"}")

JOB_ID=$(echo "$JOB" | sed -n 's/.*"path":"\/api\/reporting\/jobs\/download\/\([^"]*\)".*/\1/p')

[[ -z "$JOB_ID" ]] && echo "$JOB" && exit 1

while true; do
  sleep 5
  STATUS=$(curl -sk -b "$COOKIE_JAR" \
    "$HOST/_dashboards/api/reporting/jobs/info/$JOB_ID" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

  [[ "$STATUS" == "completed" ]] && break
  [[ "$STATUS" == "failed" ]] && exit 1
done

curl -sk -b "$COOKIE_JAR" \
 "$HOST/_dashboards/api/reporting/jobs/download/$JOB_ID" \
 -o report.csv

rm -f "$COOKIE_JAR"

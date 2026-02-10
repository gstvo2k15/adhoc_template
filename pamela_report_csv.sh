#!/usr/bin/env bash
set -euo pipefail
set +H

HOST="https://pamela-mdw.cib.echonet"

DISCOVER_PATH="/app/data-explorer/discover/#/view/81a35b70-0af4-11f0-b167-b35584ade018?_q=(filters:!(('%24state':(store:appState),meta:(alias:!n,disabled:!f,index:'59c7e1e0-0247-11ef-bc3c-ff465a6e1b4a',key:Product_dpi,negate:!f,params:!(dpi_upgraded_tomcat,tomcat,tomcat_ibmcloud_vpc,tomcat_ibm,jboss_ews,dpi_upgraded_jboss_ews),type:phrases,value:'dpi_upgraded_tomcat,%20tomcat,%20tomcat_ibmcloud_vpc,%20tomcat_ibm,%20jboss_ews,%20dpi_upgraded_jboss_ews'),query:(bool:(minimum_should_match:1,should:!((match_phrase:(Product_dpi:dpi_upgraded_tomcat)),(match_phrase:(Product_dpi:tomcat)),(match_phrase:(Product_dpi:tomcat_ibmcloud_vpc)),(match_phrase:(Product_dpi:tomcat_ibm)),(match_phrase:(Product_dpi:jboss_ews)),(match_phrase:(Product_dpi:dpi_upgraded_jboss_ews)))))),('%24state':(store:appState),meta:(alias:!n,disabled:!f,index:'59c7e1e0-0247-11ef-bc3c-ff465a6e1b4a',key:Zone,negate:!f,params:(query:IV2),type:phrase),query:(match_phrase:(Zone:IV2)))),('%24state':(store:appState),meta:(alias:!n,disabled:!f,index:'59c7e1e0-0247-11ef-bc3c-ff465a6e1b4a',key:Status,negate:!f,params:(query:ACTIVE),type:phrase),query:(match_phrase:(Status:ACTIVE))))),query:(language:kuery,query:''))&_a=(discover:(columns:!(Hostname,Os,Os_version,Product,Product_version,Environment,Status,Server_status,Instance_name,Last_update,Product_dpi,Product_patch_version,RPMVersionInstalled,Java_version,Instances_count,Region,Zone,Perimeter,Location_zone,Application_name,Ecosystem,Instances,Tomcat8,Tomcat9,Tomcat10,Jdk8rpm,Jdk11rpm,Jdk17rpm,Jdk21rpm),isDirty:!f,savedSearch:'81a35b70-0af4-11f0-b167-b35584ade018',sort:!(!(Product,asc),!(Java_version,asc),!(Last_update,desc),!(Product_version,asc)),metadata:(indexPattern:'59c7e1e0-0247-11ef-bc3c-ff465a6e1b4a')))&_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))"

DISCOVER_URL="${HOST}${DISCOVER_PATH}"
OUTPUT="${OUTPUT:-report.csv}"
COOKIE_JAR=$(mktemp)

read -r -p "User: " USER
read -r -s -p "Password: " PASS
echo

curl -sk -c "$COOKIE_JAR" -u "$USER:$PASS" "$HOST/auth/login" >/dev/null 2>&1 || true

JOB=$(curl -sk -b "$COOKIE_JAR" \
 -H "osd-xsrf: true" \
 -H "Content-Type: application/json" \
 -XPOST "$HOST/api/reporting/generate/csv" \
 -d "{\"url\":\"$DISCOVER_URL\"}")

JOB_ID=$(echo "$JOB" | sed -n 's/.*"path":"\/api\/reporting\/jobs\/download\/\([^"]*\)".*/\1/p')
[[ -z "$JOB_ID" ]] && echo "$JOB" && exit 1

while true; do
  sleep 5
  STATUS=$(curl -sk -b "$COOKIE_JAR" \
    "$HOST/api/reporting/jobs/info/$JOB_ID" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

  [[ "$STATUS" == "completed" ]] && break
  [[ "$STATUS" == "failed" ]] && exit 1
done

curl -sk -b "$COOKIE_JAR" \
 "$HOST/api/reporting/jobs/download/$JOB_ID" \
 -o "$OUTPUT"

rm -f "$COOKIE_JAR"

# adhoc_template
Basic repo for launch adhoc_template in tower

## Usage
```bash
awx -k job_templates launch 'NOMBRE_DEL_WRAPPER' \
  --extra_vars '{"region":"APAC","envs":"DEV","product":"sso_as_a_service_apac_dev_core","update":true}' \
  --verbosity 0 \
  --monitor \
  -f human | tee -a "${logfile}"
```



Examples for `run_all_limits.sh`:

```bash
# tomcat family, two envs, 3 parallel submits, 45s between submits (recommended with --no-monitor)
./run_limits.sh -r EMEA -e DEV,STG -p tomcat -u update -d prod -t false -j 3 -s 45 --no-monitor

# single real product
./run_limits.sh -r EMEA -e DEV -p tomcat_ibm -u update -d prod -t false -j 2 -s 60 --no-monitor

# everything, one env
./run_limits.sh -r APAC -e PRD -u install -d prod -t true -j 2 -s 60 --no-monitor
```
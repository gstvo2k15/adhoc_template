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

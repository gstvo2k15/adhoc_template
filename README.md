# adhoc_template
Basic repo for launch adhoc_template in tower

## Usage
```bash
awx --conf.host https://TU_TOWER \
    --conf.token 'TU_TOKEN' \
    --conf.insecure \
    job_templates launch NOMBRE_DEL_WRAPPER \
    --extra_vars '{"region":"EMEA","envs":"PRD","product":"sso_as_a_service_emea_prd_core","update":true}' \
    --monitor
```
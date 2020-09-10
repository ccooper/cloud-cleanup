# Common usage

```bash
mkdir -p logs
time ./delete_old_resources_gcp.bash 2>&1 | tee logs/DORG-output-`date +%Y%m%d%H%M%S`.log
```

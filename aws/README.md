# Common usage

```bash
for ACCOUNT in firefoxci community; do
    time ./terminate_long_running_instances.py --account ${ACCOUNT} 2>&1 | tee logs/LRI-output-${ACCOUNT}-`date +%Y%m%d%H%M%S`.log
done
```

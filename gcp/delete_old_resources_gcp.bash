#!/bin/bash

CURRENT_TS=`date +%Y%m%d%H%M%S`
DATE_THRESHOLD=2020-05-30
DRY_RUN="--dry-run"

INSTANCES_FILE=data/GCP-${DATE_THRESHOLD}-instances-${CURRENT_TS}.json
gcloud compute instances list --filter="creationTimestamp<${DATE_THRESHOLD}" --format json > ${INSTANCES_FILE}
num_instances=`cat ${INSTANCES_FILE} | jq -r '.[].name' | wc -l | awk '{$1=$1};1'`
echo "Found ${num_instances} instances"
if [ $num_instances -gt 0 ]; then
    j=0
    IFS=$'\n'
    for entry in `jq -c '.[]' ${INSTANCES_FILE}`; do
        # Get name
        name=`echo ${entry} | jq -r '.name'`
        # Get zone
        zone=`echo ${entry} | jq -r '.zone | split("/") | last'`
        if [ "${zone}" == "" ]; then
            echo "ERROR: no zone for instance ${name}"
            continue
        fi
        if [ ${DRY_RUN} ]; then
            echo "DRYRUN: gcloud compute instances delete ${name} --zone ${zone}"
        else
            echo "Deleting ${name}..."
            gcloud compute instances delete ${name} --zone ${zone} --quiet
            if [ $? == 0 ]; then
                j=$((j+1))
            fi
        fi
    done
    echo "Deleted ${j} instances"
fi

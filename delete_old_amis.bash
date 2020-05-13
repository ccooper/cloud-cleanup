#!/bin/bash

AWS_PROFILE=mfa
REGIONS="eu-central-1 us-east-1 us-west-1 us-west-2"
DATE_THRESHOLD=2019-01-01
#DRY_RUN="--dry-run"

mkdir -p data

for REGION in ${REGIONS}; do
    echo "Processing ${REGION}..."

    IMAGES_FILE=data/${REGION}-${DATE_THRESHOLD}-AMIs.json
    aws ec2 --region ${REGION} describe-images --profile ${AWS_PROFILE} --owner self --query 'Images[?CreationDate < `'${DATE_THRESHOLD}'`].ImageId' > ${IMAGES_FILE}
    num_rows=$((`wc -l ${IMAGES_FILE} | awk {'print $1'}`-2))
    if [ $num_rows -lt 0 ]; then
        num_rows=0
    fi
    echo "  Found $num_rows images"
    j=0
    for id in `cat ${IMAGES_FILE} | jq -r '.[]'`; do
        echo "    Deregistering image ${id}..."
        aws ec2 --region ${REGION} deregister-image ${DRY_RUN} --profile ${AWS_PROFILE} --image-id ${id}
        if [ $? == 0 ]; then
            j=$((j+1))
        fi
    done
    echo "  Deregistered ${j} images"

    SNAPSHOTS_FILE=data/${REGION}-${DATE_THRESHOLD}-snapshots.json
    aws ec2 --region ${REGION} describe-snapshots --profile ${AWS_PROFILE} --owner self  --query 'Snapshots[?StartTime < `'${DATE_THRESHOLD}'`].SnapshotId' > ${SNAPSHOTS_FILE}
    num_rows=$((`wc -l ${SNAPSHOTS_FILE} | awk {'print $1'}`-2))
    if [ $num_rows -lt 0 ]; then
        num_rows=0
    fi
    echo "  Found $num_rows snapshots"
    j=0
    for id in `cat ${SNAPSHOTS_FILE} | jq -r '.[]'`; do
        echo "    Deleting snapshot ${id}..."
        aws ec2 --region ${REGION} delete-snapshot ${DRY_RUN} --profile mfa --snapshot-id ${id}
        if [ $? == 0 ]; then
            j=$((j+1))
        fi
    done
    echo "  Deleted ${j} snapshots"
done

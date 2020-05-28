#!/bin/bash

AWS_PROFILE=firefoxci
REGIONS="eu-central-1 us-east-1 us-west-1 us-west-2"
DATE_THRESHOLD=2019-01-01
DRY_RUN="--dry-run"

mkdir -p data

for REGION in ${REGIONS}; do
    echo "Processing ${REGION}..."

    IMAGES_FILE=data/${REGION}-${DATE_THRESHOLD}-AMIs.json
    aws --profile ${AWS_PROFILE} ec2 --region ${REGION} describe-images --owner self --query 'Images[?CreationDate < `'${DATE_THRESHOLD}'`].ImageId' > ${IMAGES_FILE}
    num_rows=$((`wc -l ${IMAGES_FILE} | awk {'print $1'}`-2))
    if [ $num_rows -lt 0 ]; then
        num_rows=0
    fi
    echo "  Found $num_rows images"
    j=0
    for id in `cat ${IMAGES_FILE} | jq -r '.[]'`; do
        echo "    Deregistering image ${id}..."
        aws --profile ${AWS_PROFILE} ec2 --region ${REGION} deregister-image ${DRY_RUN} --image-id ${id}
        if [ $? == 0 ]; then
            j=$((j+1))
        fi
    done
    echo "  Deregistered ${j} images"

    SNAPSHOTS_FILE=data/${REGION}-${DATE_THRESHOLD}-snapshots.json
    aws --profile ${AWS_PROFILE} ec2 --region ${REGION} describe-snapshots --owner self  --query 'Snapshots[?StartTime < `'${DATE_THRESHOLD}'`].SnapshotId' > ${SNAPSHOTS_FILE}
    num_rows=$((`wc -l ${SNAPSHOTS_FILE} | awk {'print $1'}`-2))
    if [ $num_rows -lt 0 ]; then
        num_rows=0
    fi
    echo "  Found $num_rows snapshots"
    j=0
    for id in `cat ${SNAPSHOTS_FILE} | jq -r '.[]'`; do
        echo "    Deleting snapshot ${id}..."
        aws --profile ${AWS_PROFILE} ec2 --region ${REGION} delete-snapshot ${DRY_RUN} --snapshot-id ${id}
        if [ $? == 0 ]; then
            j=$((j+1))
        fi
    done
    echo "  Deleted ${j} snapshots"

    VOLUMES_FILE=data/${REGION}-${DATE_THRESHOLD}-volumes.json
    aws --profile ${AWS_PROFILE} ec2 --region ${REGION} describe-volumes --filter Name=status,Values=available --query 'Volumes[].VolumeId' > ${VOLUMES_FILE}
    num_rows=$((`wc -l ${VOLUMES_FILE} | awk {'print $1'}`-2))
    if [ $num_rows -lt 0 ]; then
        num_rows=0
    fi
    echo "  Found $num_rows volumes"
    j=0
    for id in `cat ${VOLUMES_FILE} | jq -r '.[]'`; do
        echo "    Deleting volume ${id}..."
        aws --profile ${AWS_PROFILE} ec2 --region ${REGION} delete-volume ${DRY_RUN} --volume-id ${id}
        if [ $? == 0 ]; then
            j=$((j+1))
        fi
    done
    echo "  Deleted ${j} volumes"
done

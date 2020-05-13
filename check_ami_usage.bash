#!/bin/bash

AWS_PROFILE=mfa
REGIONS="eu-central-1 us-east-1 us-west-1 us-west-2"
DATE_THRESHOLD=2019-11-09

CI_CONFIG_DIR=~/mozilla/repos/ci-configuration
COMMUNITY_CONFIG_DIR=~/mozilla/repos/community-tc-config

echo "Updating config repos..."
pushd ${CI_CONFIG_DIR}
hg pull && hg update -r default
popd

pushd ${COMMUNITY_CONFIG_DIR}
git pull
popd

echo

mkdir -p logs
mkdir -p data

for REGION in ${REGIONS}; do
    IMAGES_FILE=data/${REGION}-${DATE_THRESHOLD}-AMIs.json
    aws ec2 --region ${REGION} describe-images --profile ${AWS_PROFILE} --owner self --query 'Images[?CreationDate < `'${DATE_THRESHOLD}'`].ImageId' > ${IMAGES_FILE}
    num_amis=`cat ${IMAGES_FILE} | jq -r '. | length'`
    echo "${REGION}: Found ${num_amis} AMIs..."

    AMIS_TO_DELETE=logs/${REGION}-${DATE_THRESHOLD}-deletable.txt
    for id in `cat ${IMAGES_FILE} | jq -r '.[]'`; do
        # Check if we are current running this AMI anywhere
        num_reservations=`aws ec2 --region ${REGION} describe-instances --profile ${AWS_PROFILE} --filter Name=image-id,Values=${id} | jq -r '.Reservations | length'`
        if [ ${num_reservations} -gt 0 ]; then
            echo "${REGION}: AMI ${id} in use by ${num_reservations} reservations"
            continue
        fi

        grep -q -r ${id} ${CI_CONFIG_DIR}/*
        if [ $? -eq 0 ]; then
            echo "${REGION}: AMI ${id} referenced in ci-configuration for firefox"
            continue
        fi

        grep -q -r ${id} ${COMMUNITY_CONFIG_DIR}/*
        if [ $? -eq 0 ]; then
            echo "${REGION}: AMI ${id} referenced in community-tc-config"
            continue
        fi

        echo "${REGION}: No references to AMI ${id}. Adding to deletable list."
        echo ${id} >> ${AMIS_TO_DELETE}
    done
    echo
done

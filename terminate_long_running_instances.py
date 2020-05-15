#!/usr/bin/env python

import argparse
import boto3
import pprint
import pytz

from botocore.exceptions import ClientError
from datetime import datetime, timedelta

'''
Here's the type of query we're tryp to replicate using boto3:

 aws ec2 --profile mfa --region us-west-1 describe-instances \
         --query 'Reservations[].Instances[?LaunchTime<=`2020-05-10`][].{launched: LaunchTime, id: InstanceId}'
'''

# boto3.set_stream_logger('', level=1)
pp = pprint.PrettyPrinter(indent=4)


def is_instance_terminated(instance):
    if instance['State']['Name'] == 'terminated':
        return True
    return False


def is_instance_a_worker(instance):
    for tag in instance['Tags']:
        if tag['Key'] == 'CreatedBy' and tag['Value'] == 'taskcluster-wm-aws':
            return True
    return False


def get_instance_name(instance):
    for tag in instance['Tags']:
        if tag['Key'] == 'Name':
            return tag['Value']
    return ''


def check_termination_result(response):
    if 'TerminatingInstances' in response:
        instance = response['TerminatingInstances'][0]
        if instance['CurrentState']['Name'] in ['shutting-down', 'terminated']:
            return True
    return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dryrun", help="Dry run only, no actualy instance termination", action="store_true"
    )
    args = parser.parse_args()

    DRY_RUN = False
    if args.dryrun:
        DRY_RUN = True
    AWS_PROFILE = 'mfa'
    REGIONS = [
            'eu-central-1',
            'us-east-1',
            'us-west-1',
            'us-west-2',
            ]
    NUM_DAYS = 5
    date_threshold = datetime.utcnow().replace(tzinfo=pytz.utc) - timedelta(days=NUM_DAYS)

    session = boto3.session.Session(profile_name=AWS_PROFILE)
    for region in REGIONS:
        client = session.client('ec2',
                                region_name=region)
        paginator = client.get_paginator('describe_instances')
        page_iterator = paginator.paginate()
        # filtered_iterator = page_iterator.query('Reservations[].Instances[?LaunchTime < `2020-05-10`][]')
        instances_to_terminate = []
        for page in page_iterator:
            for reservation in page['Reservations']:
                for instance in reservation['Instances']:
                    if instance['LaunchTime'] <= date_threshold:
                        # XXX: Add other match criteria here
                        # Only worry about instances not already marked as terminated.
                        if is_instance_terminated(instance):
                            continue
                        if is_instance_a_worker(instance):
                            print("%s: %s %s %s" % (region,
                                                    str(instance['LaunchTime']),
                                                    instance['InstanceId'],
                                                    get_instance_name(instance)))
                            instances_to_terminate.append(instance['InstanceId'])

        print("%s: %d instances found" % (region, len(instances_to_terminate)))
        for id in instances_to_terminate:
            try:
                print('%s: Attempting to delete instance %s...' % (region, id), end='')
                response = client.terminate_instances(
                    InstanceIds=[id],
                    DryRun=DRY_RUN
                    )
                if check_termination_result(response):
                    print('DONE')
                else:
                    print('FAILED')
                    pp.pprint(response)
            except ClientError as e:
                if 'DryRunOperation' not in str(e):
                    raise
                else:
                    print('SKIPPED')

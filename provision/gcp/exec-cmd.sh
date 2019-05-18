#!/bin/bash
# set -x

# project details
project="zeelos-io-241010"
user="zeelos_dev_3_gmail_com"

# Google GCP region/zone
region="europe-west3"
zone="a"

# used as prefix for resources
network="$project-$region-$zone"

# Docker Swarm spec.
managers=3
workers=6

cmd="$1"

for id in $(seq 1 $managers); do
    echo "'$network-swarm-manager-$id': '$cmd' "
    gcloud compute ssh "$user@$network-swarm-manager-$id" --quiet --internal-ip --zone=$region-$zone \
    --command "sudo $cmd"
done

for id in $(seq 1 $workers); do
    echo "'$network-swarm-worker-$id': '$cmd' "
    gcloud compute ssh "$user@$network-swarm-worker-$id" --internal-ip --zone=$region-$zone \
    --command "sudo $cmd"
done

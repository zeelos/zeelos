#!/bin/bash
# set -x

# the project id
project="zeelos"

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
    gcloud compute ssh "$network-swarm-manager-$id" --internal-ip \
    --command "sudo $cmd"
done

for id in $(seq 1 $workers); do
    echo "'$network-swarm-worker-$id': '$cmd' "
    gcloud compute ssh "$network-swarm-worker-$id" --internal-ip \
    --command "sudo $cmd"
done

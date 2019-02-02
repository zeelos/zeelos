#!/bin/bash
# set -x

project="zeelos"

region="europe-west3"
zone="a"

network="$project-$region-$zone"
ip_subnet="subnet-$network"
ip_range="10.180.0.0/20"

ip_vpn_internal="192.168.1.0/24"

managers=3
workers=6
manager_machine_type="n1-standard-1"
worker_machine_type="n1-standard-1"
bastion_machine_type="n1-highcpu-2"

image="opensuse-leap-15"
image_project="zeelos-io"

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

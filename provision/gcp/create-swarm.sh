#!/bin/bash
# set -x

# project details
project="zeelos-io-241010"
user=""

# Google GCP region/zone
region="europe-west3"
zone="a"

# used as prefix for resources
network="$project-$region-$zone"

# Docker Swarm spec.
managers=3
workers=6

# check if username is configured
if [ -z "$user" ]; then
    echo "\$user is empty!"
 s   exit 1
fi

first_manager_ip=$(gcloud compute instances describe \
    --zone $region-$zone \
    --format 'value(networkInterfaces[0].networkIP)' \
$network-swarm-manager-1)

echo "initializing swarm cluster on first manager '$network-swarm-manager-1' ($first_manager_ip).."
gcloud compute ssh "$user@$network-swarm-manager-1" --internal-ip --zone=$region-$zone \
--command="docker swarm init --advertise-addr $first_manager_ip"

echo "retrieving manager token for manager node '$network-swarm-manager-1'.."
manager_token=$(gcloud compute ssh $user@$network-swarm-manager-1 --internal-ip --zone=$region-$zone \
--command="docker swarm join-token manager | grep token | awk '{ print \$5 }'")

echo "manager token retrieved: '$manager_token', attempting to join manager followers.."
for id in $(seq 2 $managers); do
    echo "joining manager node '$network-swarm-manager-$id..'"
    gcloud compute ssh "$user@$network-swarm-manager-$id" --internal-ip --zone=$region-$zone \
    --command="docker swarm join --token $manager_token $first_manager_ip:2377"
done

echo "retrieving worker token from manager node '$network-swarm-manager-1'.."
worker_token=$(gcloud compute ssh $user@$network-swarm-manager-1 --internal-ip --zone=$region-$zone \
--command="docker swarm join-token worker | grep token | awk '{ print \$5 }'")

echo "worker token retrieved: '$worker_token', attempting to join worker nodes.."
for id in $(seq 1 $workers); do
    echo "joining worker node '$network-swarm-worker-$id..'"
    gcloud compute ssh "$user@$network-swarm-worker-$id" --internal-ip --zone=$region-$zone \
    --command="docker swarm join --token $worker_token $first_manager_ip:2377"
done

echo
echo "Have a lot of fun..."
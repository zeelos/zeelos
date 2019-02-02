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

first_manager_ip=$(gcloud compute instances describe \
    --zone $zone \
    --format 'value(networkInterfaces[0].networkIP)' \
$network-swarm-manager-1)

echo "initializing swarm cluster on first manager '$network-swarm-manager-1' ($first_manager_ip).."
gcloud compute ssh "$network-swarm-manager-1" --internal-ip \
--command "sudo docker swarm init --advertise-addr $first_manager_ip"

echo "retrieving manager token for manager node '$network-swarm-manager-1'.."
manager_token=$(gcloud compute ssh $network-swarm-manager-1 --internal-ip \
--command "sudo docker swarm join-token manager | grep token | awk '{ print \$5 }'")

echo "manager token retrieved, attempting to join manager followers.."
for id in $(seq 2 $managers); do
    echo "joining manager node '$network-swarm-manager-$id..'"
    gcloud compute ssh "$network-swarm-manager-$id" --internal-ip \
    --command "sudo docker swarm join --token $manager_token $first_manager_ip:2377"
done

echo "retrieving worker token from manager node '$network-swarm-manager-1'.."
worker_token=$(gcloud compute ssh $network-swarm-manager-1 --internal-ip \
--command "sudo docker swarm join-token worker | grep token | awk '{ print \$5 }'")

echo "worker token retrieved, attempting to join worker nodes.."
for id in $(seq 1 $workers); do
    echo "joining worker node '$network-swarm-worker-$id..'"
    gcloud compute ssh "$network-swarm-worker-$id" --internal-ip \
    --command "sudo docker swarm join --token $worker_token $first_manager_ip:2377"
done
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
workers=4
manager_machine_type="n1-standard-1"
worker_machine_type="n1-standard-1"
bastion_machine_type="n1-highcpu-2"

image="opensuse-leap-15"
image_project="zeelos-io"

# create network and subnet
echo "creating network '$network'.."
gcloud compute networks create "$network" --subnet-mode custom
echo "creating subnet '$ip_subnet'.."
gcloud compute networks subnets create "$ip_subnet" \
--network "$network" \
--region "$region" \
--range "$ip_range"

echo "reserving a static external ip for bastion '$network-bastion-host-external-ip'.."
gcloud compute addresses create "$network-bastion-host-external-ip" \
--region "$region"

echo "reserving a static ip for bastion '$network-bastion-host-ip'.."
gcloud compute addresses create "$network-bastion-host-ip" \
--subnet "$ip_subnet" \
--region "$region"

echo "creating 'bastion' host for network '$network'.."
gcloud compute instances create "$network-bastion-host" \
--image "$image" \
--image-project "$image_project" \
--zone "$zone" \
--machine-type="$bastion_machine_type" \
--network "$network" \
--subnet "$ip_subnet" \
--private-network-ip="$network-bastion-host-ip" \
--address="$network-bastion-host-external-ip" \
--tags=bastion \
--boot-disk-size=10GB \
--can-ip-forward

echo "creating 'managers'.."
for id in $(seq 1 $managers); do
    echo "assigning static ip for manager '$network-swarm-manager-ip-$id'.."
    gcloud compute addresses create "$network-swarm-manager-ip-$id" \
    --subnet "$ip_subnet" \
    --region "$region"
    
    echo "creating manager '$network-swarm-manager-$id'.."
    gcloud compute instances create "$network-swarm-manager-$id" \
    --image "$image" \
    --image-project "$image_project" \
    --zone "$zone" \
    --machine-type="$manager_machine_type" \
    --boot-disk-size=10GB \
    --tags=manager \
    --can-ip-forward \
    --private-network-ip="$network-swarm-manager-ip-$id" \
    --network "$network" \
    --subnet "$ip_subnet" \
    --no-address
done

echo "creating 'workers'.."
for id in $(seq 1 $workers); do
    echo "assigning static ip for worker '$network-swarm-worker-ip-$id'.."
    gcloud compute addresses create "$network-swarm-worker-ip-$id" \
    --subnet "$ip_subnet" \
    --region "$region"
    
    echo "creating worker '$network-swarm-worker-$id'.."
    gcloud compute instances create "$network-swarm-worker-$id" \
    --image "$image" \
    --image-project "$image_project" \
    --zone "$zone" \
    --machine-type="$worker_machine_type" \
    --boot-disk-size=10GB \
    --tags=worker \
    --private-network-ip="$network-swarm-worker-ip-$id" \
    --network "$network" \
    --subnet "$ip_subnet" \
    --no-address
done

echo "creating NAT router to allow external access for internal-only hosts.."
gcloud compute routers create "$network-nat-router" \
--network "$network" \
--region "$region"

gcloud compute routers nats create "$network-nat-config" \
--router-region "$region" \
--router "$network-nat-router" \
--nat-all-subnet-ip-ranges \
--auto-allocate-nat-external-ips

echo "creating firewall rule (allow:icmp).."
gcloud compute firewall-rules create "$network-allow-icmp" \
--network "$network" \
--allow icmp \
--priority=65534

echo "creating firewall rule (allow:ssh).."
gcloud compute firewall-rules create "$network-allow-ssh" \
--network "$network" \
--allow tcp:22

echo "creating firewall rule (allow:wireguard).."
gcloud compute firewall-rules create "$network-allow-wireguard" \
--network "$network" \
--allow udp:51820,udp:53,tcp:53

echo "creating firewall rule (allow:swarm).."
gcloud compute firewall-rules create "$network-allow-swarm" \
--network "$network" \
--allow tcp:2376,tcp:2377,tcp:7946,udp:7946,udp:4789

echo "creating firewall rule (allow:portainer-ui).."
gcloud compute firewall-rules create "$network-allow-portainer-ui" \
--network "$network" \
--target-tags "manager" \
--allow tcp:9000

echo "creating firewall rule (allow:portainer-agent).."
gcloud compute firewall-rules create "$network-allow-portainer-agent" \
--network "$network" \
--allow tcp:9001

echo "creating firewall rule (allow:kafka-broker-zookeeper).."
gcloud compute firewall-rules create "$network-allow-kafka-broker-zookeeper" \
--network "$network" \
--allow tcp:2181,tcp:9580,tcp:9092,tcp:9581

echo "creating firewall rule (allow:kafka-schema-registry).."
gcloud compute firewall-rules create "$network-allow-kafka-zookeeper" \
--network "$network" \
--allow tcp:8081,tcp:9582

echo "creating firewall rule (allow:kafka-rest).."
gcloud compute firewall-rules create "$network-allow-kafka-zookeeper" \
--network "$network" \
--allow tcp:8082,tcp:9583

echo "creating route to VPN internal hosts.."
gcloud compute routes create "$network-route-to-vpn-internal-hosts" \
--destination-range="$ip_vpn_internal" \
--network="$network" \
--next-hop-instance="$network-bastion-host" \
--next-hop-instance-zone="$zone"

echo
echo "Have a lot of fun..."
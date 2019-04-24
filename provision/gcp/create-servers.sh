#!/bin/bash
# set -x

# the project id
project="zeelos-234311"

# Google GCP region/zone
region="europe-west3"
zone="a"

# used as prefix for resources
network="$project-$region-$zone"
ip_subnet="subnet-$network"
ip_range="10.180.0.0/20"

# VPN network
ip_vpn_external="94.64.15.45"
ip_vpn_internal="192.168.1.0/24"

# Docker Swarm spec.
managers=3
workers=6

# bastion host specs.
bastion_cpu="1"
bastion_mem="1GB"

# manager host specs.
manager_cpu="1"
manager_mem="1GB"

# worker host specs.
worker_cpu="2"
worker_mem="3840MB"

# base Linux image OS used on all hosts
image="debian-9-stretch"
image_project="zeelos-234311"

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
--zone "$region-$zone" \
--custom-cpu="$bastion_cpu" \
--custom-memory="$bastion_mem" \
--network "$network" \
--subnet "$ip_subnet" \
--private-network-ip="$network-bastion-host-ip" \
--address="$network-bastion-host-external-ip" \
--tags="bastion" \
--boot-disk-size=10GB \
--scopes="compute-rw,storage-full,service-control,service-management,logging-write,monitoring-write,trace" \
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
    --zone "$region-$zone" \
    --custom-cpu="$manager_cpu" \
    --custom-memory="$manager_mem" \
    --boot-disk-size=10GB \
    --tags="docker,manager" \
    --can-ip-forward \
    --private-network-ip="$network-swarm-manager-ip-$id" \
    --network "$network" \
    --subnet "$ip_subnet" \
    --scopes="compute-rw,storage-full,service-control,service-management,logging-write,monitoring-write,trace" \
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
    --zone "$region-$zone" \
    --custom-cpu="$worker_cpu" \
    --custom-memory="$worker_mem" \
    --boot-disk-size=10GB \
    --tags="docker,worker" \
    --private-network-ip="$network-swarm-worker-ip-$id" \
    --network "$network" \
    --subnet "$ip_subnet" \
    --scopes="compute-rw,storage-full,service-control,service-management,logging-write,monitoring-write,trace" \
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

echo "creating firewall rule (allow:wireguard-dnsmasq).."
gcloud compute firewall-rules create "$network-allow-wireguard-dnsmasq" \
--network "$network" \
--source-ranges="$ip_vpn_external,$ip_vpn_internal,$ip_range" \
--target-tags="bastion" \
--allow udp:51820,udp:53,tcp:53

echo "creating firewall rule (allow:swarm).."
gcloud compute firewall-rules create "$network-allow-swarm" \
--network "$network" \
--target-tags="docker" \
--allow tcp:2376,tcp:2377,tcp:7946,udp:7946,udp:4789

echo "creating firewall rule (allow:portainer-ui).."
gcloud compute firewall-rules create "$network-allow-portainer-ui" \
--network "$network" \
--target-tags "manager" \
--allow tcp:9000

echo "creating firewall rule (allow:portainer-agent).."
gcloud compute firewall-rules create "$network-allow-portainer-agent" \
--network "$network" \
--source-ranges="$ip_vpn_internal,$ip_range" \
--target-tags="docker,bastion" \
--allow tcp:9001

echo "creating firewall rule (allow:kafka-broker-zookeeper).."
gcloud compute firewall-rules create "$network-allow-kafka-broker-zookeeper" \
--network "$network" \
--target-tags="worker" \
--allow tcp:2181,tcp:9580,tcp:9092,tcp:9581

echo "creating firewall rule (allow:kafka-broker-zookeeper-edge).."
gcloud compute firewall-rules create "$network-allow-kafka-broker-zookeeper-edge" \
--network "$network" \
--source-ranges="$ip_vpn_internal,$ip_range" \
--target-tags="worker,bastion" \
--allow tcp:2171,tcp:9575,tcp:9082,tcp:9571

echo "creating firewall rule (allow:kafka-schema-registry).."
gcloud compute firewall-rules create "$network-allow-kafka-schema-registry" \
--network "$network" \
--target-tags="worker" \
--allow tcp:8081,tcp:9582

echo "creating firewall rule (allow:kafka-rest).."
gcloud compute firewall-rules create "$network-allow-kafka-rest" \
--network "$network" \
--target-tags="worker" \
--allow tcp:8082,tcp:9583

echo "creating firewall rule (allow:kafka-connect-influxdb).."
gcloud compute firewall-rules create "$network-allow-kafka-connect-influxdb" \
--network "$network" \
--target-tags="worker" \
--allow tcp:8083,tcp:9584

echo "creating firewall rule (allow:kafka-connect-asset).."
gcloud compute firewall-rules create "$network-allow-kafka-connect-asset" \
--network "$network" \
--target-tags="worker" \
--allow tcp:8084,tcp:9585

echo "creating firewall rule (allow:kafka-mirrormaker).."
gcloud compute firewall-rules create "$network-allow-kafka-mirrormaker" \
--network "$network" \
--target-tags="worker" \
--allow tcp:9574

echo "creating firewall rule (allow:orientdb).."
gcloud compute firewall-rules create "$network-allow-orientdb" \
--network "$network" \
--target-tags="worker" \
--allow tcp:2424,tcp:2480,tcp:9450

echo "creating firewall rule (allow:influxdb).."
gcloud compute firewall-rules create "$network-allow-influxdb" \
--network "$network" \
--target-tags="worker" \
--allow tcp:8086

echo "creating firewall rule (allow:grafana).."
gcloud compute firewall-rules create "$network-allow-grafana" \
--network "$network" \
--target-tags="worker" \
--allow tcp:3000

echo "creating firewall rule (allow:docker-metrics).."
gcloud compute firewall-rules create "$network-allow-docker-metrics" \
--network "$network" \
--target-tags="docker" \
--allow tcp:9323

echo "creating firewall rule (allow:prom-alertm-unsee-cadvisor).."
gcloud compute firewall-rules create "$network-allow-prom-alertm-unsee-cadvisor" \
--network "$network" \
--target-tags="worker" \
--allow tcp:9091,tcp:9093,tcp:9094,tcp:8090

echo "creating route to VPN internal hosts.."
gcloud compute routes create "$network-route-to-vpn-internal-hosts" \
--destination-range="$ip_vpn_internal" \
--network="$network" \
--next-hop-instance="$network-bastion-host" \
--next-hop-instance-zone="$region-$zone"

echo
echo "Have a lot of fun..."
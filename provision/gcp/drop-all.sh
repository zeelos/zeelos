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

echo "deleting route to VPN internal hosts.."
gcloud compute routes delete "$network-route-to-vpn-internal-hosts"

echo "deleting firewall rule (allow:icmp).."
gcloud  --quiet compute firewall-rules delete "$network-allow-icmp"

echo "deleting firewall rule (allow:ssh).."
gcloud --quiet compute firewall-rules delete "$network-allow-ssh"

echo "deleting firewall rule (allow:wireguard).."
gcloud --quiet compute firewall-rules delete "$network-allow-wireguard"

echo "deleting firewall rule (allow:swarm).."
gcloud --quiet compute firewall-rules delete "$network-allow-swarm"

echo "deleting firewall rule (allow:portainer-ui).."
gcloud --quiet compute firewall-rules delete "$network-allow-portainer-ui"

echo "deleting firewall rule (allow:portainer-agent).."
gcloud --quiet compute firewall-rules delete "$network-allow-portainer-agent"

echo "deleting firewall rule (allow:kafka-broker-zookeeper).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-broker-zookeeper"

echo "deleting firewall rule (allow:kafka-schema-registry).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-schema-registry"

echo "deleting firewall rule (allow:kafka-rest).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-rest"

echo "deleting firewall rule (allow:kafka-connect-influxdb).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-connect-influxdb"

echo "deleting firewall rule (allow:kafka-connect-asset).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-connect-asset"

echo "deleting firewall rule (allow:orientdb).."
gcloud --quiet compute firewall-rules delete "$network-allow-orientdb"

echo "deleting firewall rule (allow:influxdb).."
gcloud --quiet compute firewall-rules delete "$network-allow-influxdb"

echo "deleting firewall rule (allow:grafana).."
gcloud --quiet compute firewall-rules delete "$network-allow-grafana"

echo "deleting NAT router.."
gcloud --quiet compute routers nats delete "$network-nat-config" --router "$network-nat-router"
gcloud --quiet compute routers delete "$network-nat-router"

for id in $(seq 1 $managers); do    
    echo "deleting manager '$network-swarm-manager-$id'.."
    gcloud --quiet compute instances delete "$network-swarm-manager-$id"

    echo "deleting static ip for manager '$network-swarm-manager-ip-$id'.."
    gcloud --quiet compute addresses delete "$network-swarm-manager-ip-$id"
done

for id in $(seq 1 $workers); do    
    echo "deleting worker '$network-swarm-worker-$id'.."
    gcloud --quiet compute instances delete "$network-swarm-worker-$id"

    echo "deleting static ip for worker '$network-swarm-worker-ip-$id'.."
    gcloud --quiet compute addresses delete "$network-swarm-worker-ip-$id"
done

echo "deleting bastion host '$network-bastion-host'.."
gcloud --quiet compute instances delete "$network-bastion-host"

echo "deleting static ip for bastion '$network-bastion-host-ip'.."
gcloud --quiet compute addresses delete "$network-bastion-host-ip"

echo "deleting static external ip for bastion '$network-bastion-host-external-ip'.."
gcloud --quiet compute addresses delete "$network-bastion-host-external-ip" \

echo "deleting subnet '$ip_subnet'.."
gcloud --quiet compute networks subnets delete "$ip_subnet"

echo "deleting network '$network'.."
gcloud --quiet compute networks delete "$network"

echo
echo "dropped."
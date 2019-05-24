#!/bin/bash
# set -x

# the project id
project="zeelos-io-241010"

# Google GCP region/zone
region="europe-west3"
zone="a"

# used as prefix for resources
network="$project-$region-$zone"
ip_subnet="subnet-$network"

# Docker Swarm spec.
managers=3
workers=6

echo "deleting route to VPN internal hosts.."
gcloud --quiet compute routes delete "$network-route-to-vpn-internal-hosts"

echo "deleting firewall rule (allow:icmp).."
gcloud  --quiet compute firewall-rules delete "$network-allow-icmp"

echo "deleting firewall rule (allow:ssh).."
gcloud --quiet compute firewall-rules delete "$network-allow-ssh"

echo "deleting firewall rule (allow:wireguard-dnsmasq).."
gcloud --quiet compute firewall-rules delete "$network-allow-wireguard-dnsmasq"

echo "deleting firewall rule (allow:swarm).."
gcloud --quiet compute firewall-rules delete "$network-allow-swarm"

echo "deleting firewall rule (allow:portainer-ui).."
gcloud --quiet compute firewall-rules delete "$network-allow-portainer-ui"

echo "deleting firewall rule (allow:portainer-agent).."
gcloud --quiet compute firewall-rules delete "$network-allow-portainer-agent"

echo "deleting firewall rule (allow:kafka-zookeeper).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-zookeeper"

echo "deleting firewall rule (allow:kafka-zookeeper-edge).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-zookeeper-edge"

echo "deleting firewall rule (allow:kafka-schema-registry).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-schema-registry"

echo "deleting firewall rule (allow:kafka-rest).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-rest"

echo "deleting firewall rule (allow:kafka-connect-influxdb).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-connect-influxdb"

echo "deleting firewall rule (allow:kafka-connect-asset).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-connect-asset"

echo "deleting firewall rule (allow:kafka-mirrormaker).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafka-mirrormaker"

echo "deleting firewall rule (allow:orientdb).."
gcloud --quiet compute firewall-rules delete "$network-allow-orientdb"

echo "deleting firewall rule (allow:influxdb).."
gcloud --quiet compute firewall-rules delete "$network-allow-influxdb"

echo "deleting firewall rule (allow:grafana).."
gcloud --quiet compute firewall-rules delete "$network-allow-grafana"

echo "deleting firewall rule (allow:docker-metrics).."
gcloud --quiet compute firewall-rules delete "$network-allow-docker-metrics"

echo "deleting firewall rule (allow:prom-alertm-cadvisor).."
gcloud --quiet compute firewall-rules delete "$network-allow-prom-alertm-cadvisor"

echo "deleting firewall rule (allow:prom-alertm-cadvisor-edge).."
gcloud --quiet compute firewall-rules delete "$network-allow-prom-alertm-cadvisor-edge"

echo "deleting firewall rule (allow:kafkahq).."
gcloud --quiet compute firewall-rules delete "$network-allow-kafkahq"

echo "deleting NAT router.."
gcloud --quiet compute routers nats delete "$network-nat-config" --router "$network-nat-router" --region="$region"
gcloud --quiet compute routers delete "$network-nat-router" --region="$region"

for id in $(seq 1 $managers); do
    echo "deleting manager '$network-swarm-manager-$id'.."
    gcloud --quiet compute instances delete "$network-swarm-manager-$id" --zone="$region-$zone"

    echo "deleting static ip for manager '$network-swarm-manager-ip-$id'.."
    gcloud --quiet compute addresses delete "$network-swarm-manager-ip-$id" --region="$region"
done

for id in $(seq 1 $workers); do
    echo "deleting worker '$network-swarm-worker-$id'.."
    gcloud --quiet compute instances delete "$network-swarm-worker-$id" --zone="$region-$zone"

    echo "deleting static ip for worker '$network-swarm-worker-ip-$id'.."
    gcloud --quiet compute addresses delete "$network-swarm-worker-ip-$id" --region="$region"
done

echo "deleting bastion host '$network-bastion-host'.."
gcloud --quiet compute instances delete "$network-bastion-host" --zone="$region-$zone"

echo "deleting static ip for bastion '$network-bastion-host-ip'.."
gcloud --quiet compute addresses delete "$network-bastion-host-ip" --region="$region"

echo "deleting static external ip for bastion '$network-bastion-host-external-ip'.."
gcloud --quiet compute addresses delete "$network-bastion-host-external-ip" --region="$region"

echo "deleting subnet '$ip_subnet'.."
gcloud --quiet compute networks subnets delete "$ip_subnet" --region="$region"

echo "deleting network '$network'.."
gcloud --quiet compute networks delete "$network"

echo
echo "done, all GCP resources dropped."
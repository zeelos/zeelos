# enable docker
systemctl enable --now docker

# install rex-ray plugin
docker plugin install rexray/gcepd GCEPD_TAG=rexray GCEPD_CONVERTUNDERSCORES=true --grant-all-permissions

##
# wireguard
##

apt-get install -y dnsutils openresolv
https://www.wireguard.com/install/


# sample server interface
[Interface]
Address = 172.16.1.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = 51820
PrivateKey = yAK1AGYWSSZmfhOjGEwA1sh0Vcqe7h5UHB/8p4kYvkw=

[Peer]
PublicKey = HKeFjgAHyGQMIJ1veL09Kb1xHhzeZ3usdPqOxAl3pT8=
AllowedIPs = 172.16.90.0/24
Endpoint = 94.64.15.45:64273
PersistentKeepalive = 10

[Peer]
PublicKey = xOwUOQilktiMrdNskJWAk+JD4q1xrlJs54ZwwKlMpnE=
AllowedIPs = 192.168.1.0/24, 172.16.2.0/24
Endpoint = 94.64.15.45:50804
PersistentKeepalive = 10


#sample client(upboard) interface
[Interface]
Address = 172.16.2.1/24
DNS = 172.16.1.1
SaveConfig = true
ListenPort = 50804
FwMark = 0xca6c
PrivateKey = kNbWpQGSQSeuZ7H2U5TP3kXY3qBkZnykh30wUfCpwWI=

[Peer]
PublicKey = XwXq3cpB9zRuYgaWN256qfITXKSvjw1Wo4+jy6K67Xo=
AllowedIPs = 172.16.90.0/24, 172.16.2.0/24, 172.16.1.0/24, 10.180.0.0/20
Endpoint = 35.198.161.52:51820
PersistentKeepalive = 10


#sample client(uranus) interface
[Interface]
Address = 172.16.90.1
DNS = 172.16.1.1
SaveConfig = true
ListenPort = 62910
PrivateKey = 8ButEaCwz+GDNOAO9Ayn97VKIkkZO9MJRC+TejZJt2w=

[Peer]
PublicKey = XwXq3cpB9zRuYgaWN256qfITXKSvjw1Wo4+jy6K67Xo=
AllowedIPs = 10.180.0.0/20, 172.16.1.0/24, 172.16.2.0/24, 172.16.90.0/24
Endpoint = 35.246.214.153:51820
PersistentKeepalive = 10

# start at boot
systemctl enable --now wg-quick@wg0

# install dnsmasq
apt-get install dnsmasq
# edit '/etc/dnsmasq.conf' and allow incoming connections from hosts
listen-address=172.16.1.1,10.180.0.2,10.180.0.3,10.180.0.4,10.180.0.5,10.180.0.6,10.180.0.7,10.180.0.8,10.180.0.9,10.180.0.10,10.180.0.11,127.0.0.1

systemctl enable --now dnsmasq


# add /etc/hosts

172.16.1.1      gcp-vpn
172.16.2.1      upboard-vpn
172.16.90.1     uranus-vpn

10.180.0.2      zeelos-europe-west3-a-bastion-host
10.180.0.3      zeelos-europe-west3-a-swarm-manager-1
10.180.0.4      zeelos-europe-west3-a-swarm-manager-2
10.180.0.5      zeelos-europe-west3-a-swarm-manager-3
10.180.0.6      zeelos-europe-west3-a-swarm-worker-1 kafka-cloud-1 zookeeper-cloud-1
10.180.0.7      zeelos-europe-west3-a-swarm-worker-2 kafka-cloud-2 zookeeper-cloud-2
10.180.0.8      zeelos-europe-west3-a-swarm-worker-3 kafka-cloud-3 zookeeper-cloud-3
10.180.0.9      zeelos-europe-west3-a-swarm-worker-4 schema-registry-cloud rest-cloud kafka-mirrormaker-upboard
10.180.0.10     zeelos-europe-west3-a-swarm-worker-5 orientdb influxdb grafana prometheus alertmanager unsee
10.180.0.11     zeelos-europe-west3-a-swarm-worker-6 connect-influxdb connect-leshan-asset

192.168.1.10    upboard kafka-upboard-edge zookeeper-upboard-edge schema-registry-upboard-edge rest-upboard-edge leshan-server-kafka-upboard-edge kafka-mirrormaker-upboard-edge
192.168.1.23    uranus


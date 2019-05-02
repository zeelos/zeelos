# set hostname. For some reason on GCP, debian is missing '/etc/hostname' which causes node-exporter docker image to fail to boostrap
hostnamectl set-hostname <host>

# install handy utils
apt-get install sudo htop screen traceroute

# copy 'docker-remove-*' to /usr/local/bin

# edit '/etc/sysctl.conf' and add the following
# disable ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# enable forwarding
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0

# for each host add dnsmsaq entry '/etc/resolv.conf'
nameserver 10.180.0.2
# and disable update of 'resolv.conf'
# see https://wiki.debian.org/resolv.conf
sudo chattr +i /etc/resolv.conf


# install docker
https://docs.docker.com/install/linux/docker-ce/debian/

# install docker-app
https://github.com/docker/app

# append 'experimental' settings in '/etc/docker/daemon.json'
{
   "experimental": true,
   "metrics-addr": "0.0.0.0:9323"
}

# install rex-ray plugin
docker plugin install rexray/gcepd GCEPD_TAG=rexray GCEPD_CONVERTUNDERSCORES=true --grant-all-permissions

# install openjdk
apt-get install openjdk-8-jdk-headless

# install maven
wget -qO- http://www-us.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz | tar xvz -C /opt
export MAVEN_HOME=/opt/apache-maven-3.5.4
export PATH=$PATH:$MAVEN_HOME/bin

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
Endpoint = 94.66.31.27:62910
PersistentKeepalive = 10

[Peer]
PublicKey = xOwUOQilktiMrdNskJWAk+JD4q1xrlJs54ZwwKlMpnE=
AllowedIPs = 192.168.1.10/32, 172.16.2.0/24
Endpoint = 94.66.31.27:50804
PersistentKeepalive = 10

[Peer]
PublicKey = A+ltKUGMWtX2ecJ+GJ7+VSylpuJ3fzBbpvqPa+xQ8U0=
AllowedIPs = 192.168.1.11/32, 172.16.3.0/24
Endpoint = 94.66.31.27:1028
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


#sample client(rock64) interface
[Interface]
Address = 172.16.3.1/24
DNS = 172.16.1.1
SaveConfig = true
ListenPort = 50804
FwMark = 0xca6c
PrivateKey = OGho4etV+B2rSfqtVzynKxcnPKVNYtjI1X1mvN+dYmY=

[Peer]
PublicKey = XwXq3cpB9zRuYgaWN256qfITXKSvjw1Wo4+jy6K67Xo=
AllowedIPs = 172.16.90.0/24, 172.16.3.0/24, 172.16.1.0/24, 10.180.0.0/20
Endpoint = 35.198.161.52:51820
PersistentKeepalive = 10


#sample client(uranus) interface
[Interface]
PrivateKey = 8ButEaCwz+GDNOAO9Ayn97VKIkkZO9MJRC+TejZJt2w=
ListenPort = 62910
Address = 172.16.90.1/32
DNS = 172.16.1.1

[Peer]
PublicKey = XwXq3cpB9zRuYgaWN256qfITXKSvjw1Wo4+jy6K67Xo=
AllowedIPs = 10.180.0.0/20, 172.16.1.0/24, 172.16.2.0/24, 172.16.90.0/24
Endpoint = 35.198.161.52:51820
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
10.180.0.3      zeelos-europe-west3-a-swarm-manager-1 portainer
10.180.0.4      zeelos-europe-west3-a-swarm-manager-2
10.180.0.5      zeelos-europe-west3-a-swarm-manager-3
10.180.0.6      zeelos-europe-west3-a-swarm-worker-1 kafka-cloud-1 zookeeper-cloud-1
10.180.0.7      zeelos-europe-west3-a-swarm-worker-2 kafka-cloud-2 zookeeper-cloud-2
10.180.0.8      zeelos-europe-west3-a-swarm-worker-3 kafka-cloud-3 zookeeper-cloud-3
10.180.0.9      zeelos-europe-west3-a-swarm-worker-4 schema-registry-cloud rest-cloud kafka-mirrormaker-upboard
10.180.0.10     zeelos-europe-west3-a-swarm-worker-5 orientdb influxdb grafana prometheus alertmanager unsee
10.180.0.11     zeelos-europe-west3-a-swarm-worker-6 connect-influxdb connect-leshan-asset

192.168.1.10    upboard kafka-upboard-edge zookeeper-upboard-edge schema-registry-upboard-edge rest-upboard-edge leshan-server-kafka-upboard-edge kafka-mirrormaker-upboard-edge
192.168.1.11    rock64 kafka-rock64-edge zookeeper-rock64-edge schema-registry-rock64-edge rest-rock64-edge leshan-server-kafka-rock64-edge kafka-mirrormaker-rock64-edge
192.168.1.23    uranus


# useful cmd's
./exec-cmd.sh "sudo apt-get update; sudo apt-get upgrade -y"

# install handy alias
./exec-cmd.sh "echo \"alias dk='docker'\" >> ~/.bash_aliases"


# harbor self-signed certificate
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 \
    -subj "/C=GR/ST=Athens/L=Athens/O=zeelos/OU=Personal/CN=images.zeelos.io" \
    -key ca.key \
    -out ca.crt
openssl genrsa -out images.zeelos.io.key 4096

 openssl req -sha512 -new \
    -subj "/C=GR/ST=Athens/L=Athens/O=zeelos/OU=Personal/CN=images.zeelos.io" \
    -key images.zeelos.io.key \
    -out images.zeelos.io.csr 

cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth 
subjectAltName = @alt_names

[alt_names]
DNS.1=images.zeelos.io
DNS.2=zeelos.io
DNS.3=zeelos
EOF

openssl x509 -req -sha512 -days 3650 \
   -extfile v3.ext \
   -CA ca.crt -CAkey ca.key -CAcreateserial \
   -in images.zeelos.io.csr \
   -out images.zeelos.io.crt

cp images.zeelos.io.crt /data/cert/
cp images.zeelos.io.key /data/cert/

openssl x509 -inform PEM -in images.zeelos.io.crt -out images.zeelos.io.cert

mkdir -p /etc/docker/certs.d/images.zeelos.io/
cp images.zeelos.io.cert /etc/docker/certs.d/images.zeelos.io/
cp images.zeelos.io.key /etc/docker/certs.d/images.zeelos.io/
cp ca.crt /etc/docker/certs.d/images.zeelos.io/

#edit 'harbor.cfg'
   hostname = images.zeelos.io
   ui_url_protocol = https
   ssl_cert = /data/cert/images.zeelos.io.crt
   ssl_cert_key = /data/cert/images.zeelos.io.key

./install.sh --with-notary --with-clair


# harbor let's encrypt
see https://certbot.eff.org/lets-encrypt/debianstretch-other

certbot certonly --standalone -d images.zeelos.io
./install.sh --with-notary --with-clair

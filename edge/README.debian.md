# install ntp (edge)
apt-get install ntp
systemctl enable --now ntp
verify -> ntpq -p

# install sudo, htop
apt-get install sudo htop
usermod -aG sudo upboard

# edit '/etc/sysctl.conf' and add the following
# disable ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# enable forwarding
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0

# install docker
https://docs.docker.com/install/linux/docker-ce/debian/

# enable docker privileges for user
sudo usermod -G docker -a $USER

# append 'experimental' settings in '/etc/docker/daemon.json'
{
   "experimental": true,
   "metrics-addr": "0.0.0.0:9323"
}

# enable docker
systemctl enable --now docker

# wireguard
apt-get install -y dnsutils openresolv
https://www.wireguard.com/install/

#masquerade to the internal network to allow cloud hosts to access internal hosts
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o enp3s0 -j MASQUERADE




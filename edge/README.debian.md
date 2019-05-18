# install ntp (edge)
apt-get install ntp
systemctl enable --now ntp
verify -> ntpq -p

# install handy utils
apt-get install sudo htop screen
usermod -aG sudo upboard

# copy 'docker-remove-*' to /usr/local/bin

# install handy alias
./exec-cmd.sh "echo \"alias dk='docker'\" >> ~/.bash_aliases"

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

# install docker-app
https://github.com/docker/app

# append 'experimental' settings in '/etc/docker/daemon.json'
{
   "experimental": true,
   "metrics-addr": "0.0.0.0:9323"
}

# install openjdk
apt-get install openjdk-8-jdk-headless

# install maven
wget -qO- http://www-us.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz | tar xvz -C /opt
export MAVEN_HOME=/opt/apache-maven-3.5.4
export PATH=$PATH:$MAVEN_HOME/bin

# wireguard
apt-get install -y dnsutils openresolv
https://www.wireguard.com/install/
systemctl enable --now wg-quick@wg0

#masquerade to the internal network to allow cloud hosts to access internal hosts
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o enp3s0 -j MASQUERADE

# install cockpit
echo 'deb http://deb.debian.org/debian stretch-backports main' > \
 /etc/apt/sources.list.d/backports.list
apt-get update
sudo apt-get install cockpit cockpit-docker cockpit-storaged cockpit-networkmanager

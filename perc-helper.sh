#!/usr/bin/env bash


show_help () {
cat <<EOF 
This script assumes several things,
The first of which, is that you are running this from a debian or ubuntu machine,
Secondly, it requires some dependancies to be installed.
If the dependancies are not found, then it will install them and continue. Those dependancies are as follows.
curl, tar, alien, grep, sed, awk
Once you've read this for the first time, append the following to the script to install perccli.
--no-dry-run
The command should look like this.
/path/to/this/script.sh --no-dry-run

EOF
}


install_dependancies () {
    apt -y --quiet install alien curl tar grep
}


install_perccli() {
    curl --user-agent "Script from github.com/wafflethief123/helpers-and-tools/ Please don't derez me, I'm just a program!" "https://dl.dell.com/FOLDER04470715M/1/perccli_7.1-007.0127_linux.tar.gz?uid=979e4e96-8bde-4666-2305-3b1aed3f59e9&fn=perccli_7.1-007.0127_linux.tar.gz" -o ./perccli_7.1-007.0127_linux.tar.gz
    tar xzf ./perccli_7.1-007.0127_linux.tar.gz || echo "Failed to unpack tarball! Exiting Now!" exit 1
    cd ./Linux/ || echo "Could not find required directory! Aborting!" && exit 1
    alien --to-deb --scripts --target=amd64 --install ./perccli-007.0127.0000.0000-1.noarch.rpm 
    ln -s /opt/MegaRAID/perccli/perccli64 /usr/bin/perccli

    echo "Dell PERC Raid Controller Utility has been installed!"
    echo "It can be run by the command 'perccli' "
}


get_perc_info () {
    echo "Here's some useful info about your PERC hardware and system!"
    ProductName=$(perccli /c0 show | grep -E "Product Name" | awk 'BEGIN {FS= "="};{print $2}')
    SerialNumber=$(perccli /c0 show | grep -E "Serial Number" | awk 'BEGIN {FS= "="};{print $2}')
    PhysicalVolumes=$(perccli /c0 show | grep -E "Physical Drives" | awk 'BEGIN {FS= "="};{print $2}')
    DriveGroups=$(perccli /c0 show | grep -E "Drive Groups" | awk 'BEGIN {FS= "="};{print $2}')
    VirtualDriveCount=$(perccli /c0 show | grep -E "Virtual Drives" | awk 'BEGIN {FS= "="};{print $2}')
    clear
    echo "=========================================================================="
    echo "Raid controller Model: $ProductName"
    echo "Raid controller Serial: $SerialNumber"
    echo "Physical Disk Count: $PhysicalVolumes"
    echo "Physical Disk Info:"
    get_physical_disk_info
    echo "Drive Group Count: $DriveGroups"
    echo "Virtual Drive Count: $VirtualDriveCount"
    echo "=========================================================================="
}


get_physical_disk_info () {
    PhysicalDiskCount="$(perccli /c0 show all | grep -E "Physical Drives" | awk 'BEGIN {FS= "="};{print $2}')"
    AddLines="$(("$PhysicalDiskCount" + 6))"
    perccli /c0 show all | grep -E "PD LIST" -A $AddLines
    echo "EID = Enclosure Device ID | Slt = Slot Number | DID = Device ID"
    echo "DG = Drive Group | Intf = Inteface Type | Med = Media Type"
    echo "SED = Self Encryptive Drive | PI = Protection Info"
    echo "SeSz = Sector Size | Sp = Disk Spun Up or Down"
}


###
#  End Functions
###

if [ "${1}" == "--no-dry-run" ]; then 
    install_dependancies
    install_perccli
    get_perc_info
else
    show_help
    exit 1
fi

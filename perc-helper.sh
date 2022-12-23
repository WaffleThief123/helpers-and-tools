#!/usr/bin/env bash


show_help () {
cat <<EOF 
This script assumes several things,
The first of which, is that you are running this from a debian or ubuntu machine with a PERC raid controller,
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
    cd ./Linux/ || echo "Could not find required directory! Aborting!"
    alien --to-deb --scripts --target=amd64 --install ./perccli-007.0127.0000.0000-1.noarch.rpm 
    ln -s /opt/MegaRAID/perccli/perccli64 /usr/bin/perccli

    echo "Dell PERC Raid Controller Utility has been installed!"
    echo "It can be run by the command 'perccli' "
}


install_megaraid() {
    curl --user-agent "Script from github.com/wafflethief123/helpers-and-tools/ Please don't derez me, I'm just a program!" "wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/8-07-14_MegaCLI.zip" -o ./megacli_8-07-14.zip
    unzip ./megacli_8-08-14.zip || echo "Failed to Unzip File. Aborting!" exit 1
    cd ./Linux/ || echo "Could not find required directory! Aborting!"
    alien --to-deb --scripts --target=amd64 --install ./perccli-007.0127.0000.0000-1.noarch.rpm 
    ln -s /opt/MegaRAID/MegaCli/MegaCli64 /usr/bin/megacli
    
    echo "Broadcom MegaRaid Controller Utility has been installed!"
    echo "It can be run by the command 'megacli' "
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
    echo "Column Key:"
    echo "EID = Enclosure Device ID | Slt = Slot Number | DID = Device ID"
    echo "DG = Drive Group | Intf = Inteface Type | Med = Media Type"
    echo "SED = Self Encryptive Drive | PI = Protection Info"
    echo "SeSz = Sector Size | Sp = Disk Spun Up or Down"
}

function yesnomaybe {
    while true; do
        read -p "$* [yes/no/y/n]: " yn
        case $yn in
            [Yy]*) echo "Yes recieved!" ; return 0 ;;  
            [Nn]*) echo "No recvieved!" ; return 1 ;;
            *) echo "Invalid Input Recieved, Please Try Again." ;;
        esac
    done
}

nobody_at_dell_can_agree_on_where_slot_numbers_start () {
    for i in $(TotalLines=$(echo "$(("$(perccli /c0 show all | grep -E "Physical Drives" | awk 'BEGIN {FS= "="};{print $2}')"+6))") && perccli /c0 show all | grep -E "PD LIST" -A $TotalLines | awk '{print $2}'| sed '1,6d' | sed '$d') 
    do echo "Drive Slot $i" 
    perccli /c0 /e32 /s$i show all | egrep -i "Error Count|Failure|alert flagged by drive|SN"
    echo ""
    done

}

###
#  End Functions
###

if [ "${1}" == "--no-dry-run" ]; then 
    install_dependancies
    install_perccli
    yesnomaybe "Do you want to see info about your PERC Controller and attached drives?" && get_perc_info
else
    show_help
    exit 1
fi

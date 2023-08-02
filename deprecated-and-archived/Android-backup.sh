#!/bin/bash
# This script is designed to be called by a cronjob, in order to back up your android phone whenever sent
# Maybe at somepoint i'll have  a check to verify an android device is connected, but not yet most likely
timeday = date +%s
kdialog --yesno "It's time to backup your phone!" --yes-label "Let's do it" --no-label "Maybe Later";

case "$?" in
	0)
		kdialog --msgbox "Initiating Backup now, Please unlock and confirm";
        adb backup -f /home/john/PhoneBackup/backup_$(timeday).ab
		;;
	1)
		kdialog --sorry "Okay, Don't forget to do a backup later!";
		;;
	*)
		kdialog --error "ERROR";
		;;
esac;
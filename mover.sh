#!/usr/bin/env bash
###########
#            Piracy is a crime
# So like, Don't tell anyone?
# Thanks... 
############

# Root check, tldr: get some privileges.
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

read -p "What is the parent directory of all the things you want to extract?" ExtrationDir
cd $(ExtractionDir)

# unrar all files in a directory, recursively
# Yes this works for TV series as well.
unrar e -r -o- *.rar
# Cleans up rar files when done, including all the bullshit .r00 ones
for i in {00..90}; do find . -type f -name "*.r$i" -exec rm  {} \; ; done;  find . -type f -name "*.rar" -exec rm  {} \;

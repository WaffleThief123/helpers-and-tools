#!/bin/bash

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=4
BACKTITLE="UFW Helper"
TITLE="UFW Helper"
MENU="Choose one of the following options:"
TERMINAL=$(tty)


mkdir /tmp/ufwmanager

OPTIONS=(1 "View Rules"
         2 "Add a Rule"
         3 "Delete a Rule")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >$TERMINAL
)
clear
case $CHOICE in
        1)
            clear
            echo "Here are your firewall rules"
            ufw status verbose >> /tmp/ufwmanager/rules
            cat /tmp/ufwmanager/rules
            ;;
        2)
            echo "You've chosen to add a rule"
            sleep 5
            clear
            echo ""
            echo "What port do you wish to open?"
            read openport
            ufw allow $openport
            ufw status verbose
            ;;
        3)
            echo "What port do you wish to close?"
        
            sleep 5
            clear
            echo ""
            echo "What port do you wish to open?"
            read closeport
            ufw deny $closeport
            ufw status verbose
            ;;
rm -rf /tmp/ufwmanager
esac
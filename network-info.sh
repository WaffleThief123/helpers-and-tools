#!/usr/bin/env bash

# Global arrays to hold interfaces
IFACE_ARRAY=()
BOND_ARRAY=()

# Function to populate network interfaces excluding loopback, virtual, wireless, and bond interfaces
populate_iface_array() {
    local iface
    iface_array=($(ip link | awk -F: '$0 !~ "lo|^[^0-9]"{print $2;getline}' | sed -e 's/bond[0-3]//g' | sed -r '/^\s*$/d'))
    if [[ ${#iface_array[@]} -eq 0 ]]; then
        printf "No valid network interfaces found.\n" >&2
        return 1
    fi
}

# Function to populate bond interfaces
populate_bond_array() {
    local bond
    bond_array=($(ip link | awk -F: '$0 !~ "lo|^[^0-9]"{print $2;getline}' | sed -e 's/eth.*//g' | sed -r '/^\s*$/d'))
    if [[ ${#bond_array[@]} -eq 0 ]]; then
        printf "No bond interfaces found.\n" >&2
        return 1
    fi
}

# Function to display stats for interfaces
display_iface_stats() {
    local i
    for i in "${iface_array[@]}"; do
        printf "\nInterface: %s\n" "$i"
        ethtool -S "$i" | grep -Ei "tx_error|rx_error|discards|crc|dma_readq|dma_writeq"
    done
}

# Function to display bond interface stats
display_bond_stats() {
    local i
    for i in "${bond_array[@]}"; do
        printf "\nBonded Interface %s Stats:\n" "$i"
        ethtool "$i" | grep -Ei "bond|Speed|Duplex|Detected"
    done
}

# Function to display LACP bond information
display_lacp_info() {
    printf "\nLACP Bond Information:\n"
    lldpcli show neighbors | grep -Ei "Interface|SysName|PortID"
}

# Main function to call all other functions
main() {
    populate_iface_array || exit 1
    populate_bond_array || exit 1
    display_iface_stats
    display_bond_stats
    display_lacp_info
}

# Execute main function
main

#!/bin/bash
# Script to enable port forwarding and IP Masquerading to share
# the primary internet connection on the second port of DS718+

# Usage: nat.sh [start|stop|restart]
action=$1
shift;

# Network interface and configuration file definitions
INT_IFACE="eth1"
IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-ovs_${INT_IFACE}"
DHCPD_CONF="/etc/dhcpd/dhcpd.conf"
RULES_NAT="/etc/firewall_rules_nat.dump"

# Function to log errors
logerr() { 
    TAG="nat_router"
    [ ! -z "$action" ] && TAG="${TAG} (${action})"
    logger -p user.err -t "${TAG}" "$@"
}

# Ensure necessary configuration files exist
if [ ! -e "$IFCFG_FILE" ] || [ ! -e "$DHCPD_CONF" ]; then
    logerr "Missing configuration files"
    exit 1
fi

# Fetch IP address and netmask from the network configuration file
IPADDR=$(get_key_value "$IFCFG_FILE" IPADDR)
NETMASK=$(get_key_value "$IFCFG_FILE" NETMASK)
if [ -z "$IPADDR" ] || [ -z "$NETMASK" ]; then
    logerr "IP address or netmask not set in configuration files"
    exit 1
fi

# Verify the router configuration in DHCP settings
IS_ROUTER=$(grep "option:router" "$DHCPD_CONF" | grep -c "$IPADDR")
if [ "$IS_ROUTER" -ne 1 ]; then
    logerr "Router mode not enabled or multiple entries found for $INT_IFACE"
    exit 1
fi

# Calculate CIDR notation for IP address and netmask
CIDR_PREFIX=$(ipcalc -p "$IPADDR" "$NETMASK" | cut -d'=' -f2)
CIDR_IP=$(ipcalc -n "$IPADDR" "$NETMASK" | cut -d'=' -f2)
CIDR="${CIDR_IP}/${CIDR_PREFIX}"
if [ -z "$CIDR_PREFIX" ] || [ -z "$CIDR_IP" ]; then
    logerr "Failed to calculate CIDR notation from IP address and netmask"
    exit 1
fi

# Function to set up NAT
setup_nat() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
    logerr "IP Forwarding enabled"
}

# Function to load NAT rules from file
load_nat_rules() {
    if [ -e "$RULES_NAT" ]; then
        if /sbin/iptables-restore -n < "$RULES_NAT"; then
            logerr "NAT rules loaded successfully"
        else
            logerr "Error loading NAT rules from: $RULES_NAT"
            exit 1
        fi
    else
        logerr "No NAT rules file found"
        exit 1
    fi

    # Set up IP masquerading
    if ! /sbin/iptables -t nat -D POSTROUTING -s "$CIDR" -j MASQUERADE 2> /dev/null; then
        logerr "Failed to delete existing masquerade rule, maybe none existed"
    fi
    if ! /sbin/iptables -t nat -A POSTROUTING -s "$CIDR" -j MASQUERADE; then
        logerr "Failed to append masquerade rule"
        exit 1
    fi
}

# Function to save NAT rules to a file
save_nat_rules() {
    TMP_RULES="/tmp/firewall_rules_nat.tmp"
    echo "# $(date)" > "$TMP_RULES"
    echo "*nat" >> "$TMP_RULES"
    /sbin/iptables-save -t nat | grep "\-j DNAT" | uniq >> "$TMP_RULES"
    echo "COMMIT" >> "$TMP_RULES"
    if ! mv -f "$TMP_RULES" "$RULES_NAT"; then
        logerr "Failed to save NAT rules to $RULES_NAT"
        exit 1
    fi
    logerr "NAT rules saved to $RULES_NAT"
}

# Function to clear NAT rules
clear_nat_rules() {
    /sbin/iptables-save -t nat | grep "\-j DNAT" | sed 's/^-A /-D /g' | while read line; do
        if [ ! -z "$line" ] && ! /sbin/iptables -t nat $line; then
            logerr "Failed to clear NAT rule: $line"
        fi
    done

    if ! /sbin/iptables -t nat -D POSTROUTING -s "$CIDR" -j MASQUERADE; then
        logerr "Failed to delete masquerade rule"
    fi
}

# Handle script actions
case "$action" in
    start)
        setup_nat
        load_nat_rules
        ;;
    stop)
        save_nat_rules
        clear_nat_rules
        ;;
    restart)
        save_nat_rules
        clear_nat_rules
        setup_nat
        load_nat_rules
        ;;
    *)
        echo "Usage: $0 [start|stop|restart]"
        exit 1
        ;;
esac

exit 0

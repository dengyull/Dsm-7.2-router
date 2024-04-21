# DSM-7.2-Router

Welcome to the DSM-7.2-Router README guide! This document provides detailed instructions on how to configure your Synology DiskStation running DSM 7.2 to act as a router. It includes guidance on installing and enabling the DHCP Server, setting up NAT, and configuring port forwarding using `iptables`.

## Prerequisites

Before you start, ensure you have:
- A Synology NAS running DSM 7.2.
- Administrative access to the DSM interface.
- SSH access to your NAS.

## Step 1: Installing the DHCP Server Package

DHCP Server functionality in DSM 7.2 is not built-in and must be installed manually:

### Installation Instructions

1. **Log into DSM**:
   - Open your browser and enter the IP address of your NAS to access the DSM interface.

2. **Open Package Center**:
   - Go to the main menu and click on `Package Center`.

3. **Search for DHCP Package**:
   - Type "DHCP" in the search bar and press enter.
   - Find the `DHCP Server` package in the search results.

4. **Install the DHCP Server**:
   - Click on the `Install` button next to the DHCP Server package.
   - Follow the on-screen prompts to complete the installation.

## Step 2: Configuring DHCP Server

Once installed, you can configure the DHCP server to handle IP distribution:

### Configuration Steps

1. **Access DHCP Server Settings**:
   - Navigate to `DHCP Server` from the main menu.

2. **Enable and Configure DHCP**:
   - Enable the DHCP Server by checking the appropriate box.
   - Configure your IP range, subnet mask, gateway, and other network settings.

## Step 3: Setting Up NAT

Use the `nat.sh` script to set up Network Address Translation (NAT) on your NAS,Save `nat.sh` in your preferred path, in the example here it is saved in the homes folder.

### Setup NAT Script in Task Scheduler

```bash
sh /volume1/homes/nat.sh restart
```

## Step 4: Enabling Port Forwarding

Port forwarding allows you to direct internet traffic to specific devices on your network.

### Port Forward Script in Task Scheduler

```bash
iptables -t nat -F DEFAULT_PREROUTING
iptables -t nat -A PREROUTING -p tcp --dport 51415 -j DNAT --to-destination 192.168.10.10:51415
iptables -t nat -A PREROUTING -p udp --dport 51415 -j DNAT --to-destination 192.168.10.10:51415

```


## Disclaimer

Please be cautious when modifying network settings; incorrect settings can disrupt connectivity. Always back up your configurations and data.
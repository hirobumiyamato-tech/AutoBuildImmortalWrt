#!/bin/sh
# 99-custom.sh：ImmortalWrt 首启自定义逻辑

LOGFILE="/etc/config/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >>$LOGFILE

# ===============================
# A. 基础网络 & 防火墙调整（保留你的逻辑）
# ===============================
uci set firewall.@zone[1].input='ACCEPT'

uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"

# ===============================
# B. PPPoE 动态配置（保留你的逻辑）
# ===============================
SETTINGS_FILE="/etc/config/pppoe-settings"
if [ -f "$SETTINGS_FILE" ]; then
    . "$SETTINGS_FILE"
fi

# ===============================
# C. 自动检测网口并配置（保留你的逻辑）
# ===============================
ifnames=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
        ifnames="$ifnames $iface_name"
    fi
done
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')
count=$(echo "$ifnames" | wc -w)
board_name=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "unknown")

wan_ifname=""
lan_ifnames=""

case "$board_name" in
    "radxa,e20c"|"friendlyarm,nanopi-r5c")
        wan_ifname="eth1"
        lan_ifnames="eth0"
        ;;
    *)
        wan_ifname=$(echo "$ifnames" | awk '{print $1}')
        lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
        ;;
esac

if [ "$count" -eq 1 ]; then
    uci set network.lan.proto='dhcp'
    uci delete network.lan.ipaddr
    uci delete network.lan.netmask
    uci delete network.lan.gateway
    uci delete network.lan.dns
    uci commit network
elif [ "$count" -gt 1 ]; then
    uci set network.wan=interface
    uci set network.wan.device="$wan_ifname"
    uci set network.wan.proto='dhcp'

    uci set network.wan6=interface
    uci set network.wan6.device="$wan_ifname"
    uci set network.wan6.proto='dhcpv6'

    section=$(uci show network | awk -F '[.=]' '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
    [ -n "$section" ] && uci -q delete "network.$section.ports"
    for port in $lan_ifnames; do
        uci add_list "network.$section.ports"="$port"
    done

    uci set network.lan.proto='static'
    uci set network.lan.netmask='255.255.255.0'

    IP_VALUE_FILE="/etc/config/custom_router_ip.txt"
    if [ -f "$IP_VALUE_FILE" ]; then
        CUSTOM_IP=$(cat "$IP_VALUE_FILE")
        uci set network.lan.ipaddr=$CUSTOM_IP
    else
        uci set network.lan.ipaddr='192.168.100.1'
    fi

    if [ "$enable_pppoe" = "yes" ]; then
        uci set network.wan.proto='pppoe'
        uci set network.wan.username="$pppoe_account"
        uci set network.wan.password="$pppoe_password"
        uci set network.wan.peerdns='1'
        uci set network.wan.auto='1'
        uci set network.wan6.proto='none'
    fi

    uci commit network
fi

# ===============================
# D. Docker 防火墙规则（保留）
# ===============================
if command -v dockerd >/dev/null 2>&1; then
    uci delete firewall.docker
    uci commit firewall
    cat <<EOF >>/etc/config/firewall

config zone 'docker'
  option input 'ACCEPT'
  option output 'ACCEPT'
  option forward 'ACCEPT'
  option name 'docker'
  list subnet '172.16.0.0/12'

config forwarding
  option src 'docker'
  option dest 'lan'

config forwarding
  option src 'docker'
  option dest 'wan'

config forwarding
  option src 'lan'
  option dest 'docker'
EOF
fi

# ===============================
# E. 系统 & SSH 设置（保留）
# ===============================
uci delete ttyd.@ttyd[0].interface
uci set dropbear.@dropbear[0].Interface=''
uci commit

FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Packaged by wukongdaily"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

if opkg list-installed | grep -q '^luci-app-advancedplus '; then
    sed -i '/\/usr\/bin\/zsh/d' /etc/profile
    sed -i '/\/bin\/zsh/d' /etc/init.d/advancedplus
    sed -i '/\/usr\/bin\/zsh/d' /etc/init.d/advancedplus
fi

# ===============================
# F. 自动启用 Docker（二启之后）
# ===============================
if [ -f "/etc/.autopart_done" ]; then
    echo "Autopart done, enabling Docker..." >>$LOGFILE
    /etc/init.d/dockerd enable
    /etc/init.d/dockerd start
fi

exit 0

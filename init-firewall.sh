# #!/bin/bash

ip link set enp0s8 up
dhclient enp0s8

if [ -e /proc/sys/net/ipv4/ip_forward ]
then
    echo "IP forwarding is enabled"
else
    echo 1 > /proc/sys/net/ipv4/ip_forward
fi

iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

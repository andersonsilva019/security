# #!/bin/bash

sudo netplan apply
resolvectl status | grep "DNS Server" -A2
sudo ip route add default via 192.168.57.4

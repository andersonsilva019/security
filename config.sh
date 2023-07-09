# #!/bin/bash

IP_INTERNET="$(ip addr show enp0s3 | grep 'inet ' | cut -f2 | awk '{ print $2}' | cut -d/ -f1)"

IP_WEB_SERVER="192.168.57.3:80"

printf "IP da interface enp0s3: %s\n" "$IP_INTERNET"
printf "IP do servidor WEB: %s\n" "$IP_WEB_SERVER"
sleep 0.2

if [ -z "$IP_INTERNET" ]
then
  echo "Erro ao obter o IP da interface enp0s3"
  exit 1
fi

echo "Configurando a interface da rede interna (enp0s8)"
sudo ip link set enp0s8 up
sleep 0.2
sudo dhclient enp0s8

if [ $? -ne 0 ]
then
  echo "Erro ao configurar a interface enp0s8"
  exit 1
fi

sleep 0.2
echo "Configurando a interface da rede externa (enp0s9)"
sudo ip link set enp0s9 up
sleep 0.2
sudo dhclient enp0s9

if [ $? -ne 0 ]
then
  echo "Erro ao configurar a interface enp0s9"
  exit 1
fi

sleep 0.2
echo "Habilitando o encaminhamento de pacotes (ip_forward)"
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

if [ $? -ne 0 ]
then
  echo "Erro ao habilitar o ip_forward"
  exit 1
fi

sleep 0.2
echo "############################"
echo "#  Regras para o firewall  #"
echo "############################"

sleep 0.2

# Essa regra permite que as maquinas da rede interna acessem a internet através da tradução de endereço de origem (SNAT)
# para pacotes que estão saindo da interface enp0s3 (internet)
echo "Configurar NAT para MASQUERADE"
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE


# Essas regras permitem que o firewall receba conexões SSH de qualquer lugar da rede interna
# Utilizando filtro de estado para permitir apenas conexões novas e estabelecidas
sleep 0.2
echo "Configurando regras para o SSH"
sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT


# Aplica a política DROP para todas as chains (INPUT, OUTPUT e FORWARD)
sleep 0.2
echo "Configurando as politicas padrões para DROP"
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT DROP
sudo iptables -P FORWARD DROP


# Liberando tráfego de processos internos do firewall através da interface loopback (lo)
sleep 0.2
echo "Configurando regras para processos internos do firewall"
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT


# Essas regras permitem que o firewall receba requisições de ping de qualquer lugar da rede interna
# Utilizando filtro de estado para permitir apenas conexões novas e estabelecidas.
# A regra de INPUT é necessária para permitir que o firewall receba as requisições de ping.
# A regra de OUTPUT é necessária para permitir que o firewall responda as requisições de ping.
sleep 0.2
echo "Configurando regras para o Firewall receba e responda requisições de ping"
sudo iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p icmp --icmp-type 0 -m conntrack --ctstate ESTABLISHED -j ACCEPT

# Permitir que o firewall faça consultas DNS (porta 53)
# Essas regras permitem que o Firewall realize consultas DNS para qualquer lugar da internet
# Mas não permite que o Firewall seja um servidor DNS, devido a chain INPUT não ter uma regra para aceitar requisições DNS.
sleep 0.2
echo "Configurando regras para o Firewall fazer consultas DNS" 
sudo iptables -A OUTPUT -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT  -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT

sleep 0.2
echo "##############################"
echo "#  Regras para rede cliente  #"
echo "##############################"

# Essa regra permite que o cliente realize conexões SSH para qualquer lugar da internet via Firewall.
echo "Configurando regras para o cliente fazer conexões SSH para qualquer lugar da internet via Firewall."
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT


# Essa regra permite que o cliente realize consultas DNS para qualquer lugar da internet via Firewall.
# Utilizada filtros de estado para permitir apenas conexões novas e estabelecidas.
sleep 0.2
echo "Configurando regras para o cliente fazer consultas DNS" 
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT


# Essa regra permite que o cliente realize requisições HTTP e HTTPS para qualquer lugar da internet via Firewall.
# Utilizada filtros de estado para permitir apenas conexões novas e estabelecidas.
sleep 0.2
echo "Configurando regras para o cliente fazer requisições HTTP e HTTPS"
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT


# Essa regra permite que o cliente realize requisições pings para qualquer lugar da internet via Firewall.
# Utilizada filtros de estado para permitir apenas conexões novas e estabelecidas.
sleep 0.2
echo "Configurando regras para o cliente fazer requisições de ping"
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p icmp --icmp-type 8 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT


# Essa regra permite que o cliente realize requisições FTP e SMTP utilizando o módulo multport para qualquer lugar da internet via Firewall.
# Utilizada filtros de estado para permitir apenas conexões novas e estabelecidas.
sleep 0.2
echo "Configurando regras para o cliente fazer requisições FTP e SMTP"
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp -m multiport --dports 21,25 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT


# Essa regra permite que a volta dos pacotes, de qualquer protocolo e porta, de uma conexão já estabelecidas seja permitida.
# Evitando a passagem de pacotes falsificados.
sleep 0.2
echo "Configurando regras para o cliente receber respostas de conexões já estabelecidas"
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

echo "##########################"
echo "#  Regras para rede DMZ  #"
echo "##########################"


# Essa regra permite que o Firewall encaminhe requisições HTTP vindas da internet para o servidor WEB antes do roteamento dos pacotes.
sleep 0.2
echo "Configurando regras para o Firewall encaminhar requisições HTTP vindas da internet para o servidor WEB"
sudo iptables -t nat -A PREROUTING -d $IP_INTERNET -p tcp -m tcp --dport 80 -j DNAT --to-destination $IP_WEB_SERVER

# Essa regra permite que o Firewall encaminhe requisições HTTP e HTTPS vindas da interface de internet para a interface da DMZ.
# Utilizada filtros de estado para permitir apenas conexões novas e estabelecidas.
sleep 0.2
echo "Configurando regras para o Firewall encaminhar requisições HTTP e HTTPS vindas da interface de internet para a interface da DMZ"
sudo iptables -A FORWARD -i enp0s3 -o enp0s9 -p tcp -m tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

  # Da rede interna para WEB SERVER
  #sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

  #Ping para DMZ (Está regra estava ativada, mas não sei se é necessária. Tudo funcionou com ela)
  #sudo iptables -A FORWARD -i enp0s8 -o enp0s9 -p icmp --icmp-type 8 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

sleep 0.2
echo "#########################"
echo "#  Regras para o SQUID  #"
echo "#########################"
sleep 0.2

# Essa regra permite que o Firewall redirecione requisições HTTP vindas da interface de internet para a porta 3129 do SQUID. 
echo "Redirecionando requisições HTTP vindas da interface de internet para a porta 3129 do SQUID"
sudo iptables -t nat -A PREROUTING -i enp0s8 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 3129

# Essa regra permite que o Firewall redirecione requisições HTTPS vindas da interface de internet para a porta 3130 do SQUID.
sleep 0.2
echo "Redirecionando requisições HTTPS vindas da interface de internet para a porta 3130 do SQUID"
sudo iptables -t nat -A PREROUTING -i enp0s8 -p tcp -m tcp --dport 433 -j REDIRECT --to-ports 3130

# Essa regra permite o tráfego de pacotes HTTP e HTTPS entre o Firewall e o SQUID.
sleep 0.2
echo "Configurando regras para o tráfego de pacotes HTTP e HTTPS entre o Firewall e o SQUID"
sudo iptables -A INPUT -i enp0s8 -p tcp -m tcp -m multiport --dports 3129,3130 -j ACCEPT
sudo iptables -A OUTPUT -o enp0s8 -p tcp -m tcp -m multiport --sports 3129,3130 -j ACCEPT

# Essa regra permite o tráfego de pacotes HTTP e HTTPS entre o SQUID e a internet.
echo "Configurando regras para o tráfego de pacotes HTTP e HTTPS entre o SQUID e a internet"
sudo iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Essa regra permite o tráfego de pacotes HTTP e HTTPS entre o SQUID e a DMZ.
echo "Configurando regras para o tráfego de pacotes HTTP e HTTPS entre o SQUID e a DMZ"
sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

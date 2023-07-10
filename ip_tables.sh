#!/bin/bash
declare -a NameSpaceArray=("client1" "client2" "server" "firewall")
declare -a FirewallConnection=("client1" "client2" "server")

examine_namespaces() {
	echo -e "\n=> Examine the network namespaces"
	for i in "${NameSpaceArray[@]}"
	do
		echo "== The network configuration of $i:"
		sudo ip netns exec "$i" ip addr show
	done
}

add_namespaces() {
	echo -e "\n=> Adding the network namespaces..."
	for i in "${NameSpaceArray[@]}"
	do
		sudo ip netns add "$i"
	done
}

remove_namespaces() {
	echo -e "\n=> Deleting the network namespaces..."
	for i in "${NameSpaceArray[@]}"
	do
		sudo ip netns del "$i"
	done
}


set_veth_connections() {
	echo -e "\n=> Setting veth connections..."
	for i in "${FirewallConnection[@]}"
	do
		sudo ip link add "veth-$i" type veth peer name veth-firewall
		sudo ip link set veth-firewall netns "$i"
		sudo ip link set "veth-$i" netns firewall
	done
}

activate_interfaces() {
	echo -e "\n=> Add ip addresses and activate interfaces..."
	counter=2
	sudo ip -n firewall link set lo up
	# sudo ip netns exec firewall ip route add 192.0.2.128/26 via 192.0.2.130 dev veth-server
	sudo ip netns exec firewall ip route add 192.0.2.128/26 via 192.0.2.130 dev veth-firewall
	echo "something -==="
	for i in "${FirewallConnection[@]}"
	do
		echo "$counter"
		# sudo ip link add "veth-$i" type veth peer name veth-firewall

		#sudo ip netns exec firewall ip route add 192.0.2.64/26 via 192.0.2.130
		#sudo ip netns exec firewall ip route add 192.0.2.0/26 via 192.0.2.130
		sudo ip -n "$i" link set lo up
		sudo ip -n "$i" link set veth-firewall up
		sudo ip -n firewall link set "veth-$i" up
		sudo ip -n "$i" addr add 192.0.2.$counter/26 dev veth-firewall
		((counter=counter+1))
		sudo ip -n firewall addr add 192.0.2.$counter/26 dev "veth-$i"
		((counter=counter+63))
		# ((counter++))
	done
}

test_pings() {
	echo -e "\n=> ####### Ping the hosts"
	counter=2
	for i in "${FirewallConnection[@]}"
	do
		echo "pinging..."
		sudo ip netns exec "$i" ping -c 1 192.0.2.$counter
		((counter=counter+1))
		echo "pinging..."
		sudo ip netns exec firewall ping -c 1 192.0.2.$counter
		((counter=counter+63))
		# ((counter++))
	done
}

remove_namespaces
add_namespaces
set_veth_connections
activate_interfaces
examine_namespaces

# Add Default Gateway to clients
sudo ip netns exec client2 ip route add default via 192.0.2.67 dev veth-firewall
sudo ip netns exec client1 ip route add default via 192.0.2.3 dev veth-firewall

sudo ip netns exec firewall sysctl -w net.ipv4.ip_forward=1

## SETUP ROUTES
sudo ip netns exec firewall ip route add 192.0.2.0/26 via 0.0.0.0 dev veth-client1
sudo ip netns exec firewall ip route add 192.0.2.64/26 via 0.0.0.0 dev veth-client2
sudo ip netns exec firewall ip route add 192.0.2.128/26 via 0.0.0.0 dev veth-server

sudo ip netns exec server ip route add 192.0.2.0/26 via 192.0.2.131 dev veth-firewall
sudo ip netns exec server ip route add 192.0.2.0/26 via 192.0.2.131 dev veth-firewall

# sudo ip netns exec server ip route add default via 192.0.2.131
# sudo ip netns exec server ip route add 192.0.2.128/26 via 192.0.2.2

test_pings
sudo ip netns exec server node server.js
# sudo ip netns exec firewall curl 192.0.2.130:8000
# examine_namespaces






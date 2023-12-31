#!/bin/bash
declare -a NameSpaceArray=("client1" "client2" "server" "firewall")
declare -a FirewallConnection=("client1" "client2" "server")

examine_namespaces() {
	printf "\n=> Examine the network namespaces"
	for i in "${NameSpaceArray[@]}"
	do
		echo "== The network configuration of $i:"
		sudo ip netns exec "$i" ip addr show
	done
}

add_namespaces() {
	printf "\n=> Adding the network namespaces..."
	for i in "${NameSpaceArray[@]}"
	do
		sudo ip netns add "$i"
	done
}

remove_namespaces() {
	printf "\n=> Deleting the network namespaces..."
	for i in "${NameSpaceArray[@]}"
	do
		sudo ip netns del "$i"
	done
}


set_veth_connections() {
	printf "\n=> Setting veth connections..."
	for i in "${FirewallConnection[@]}"
	do
		sudo ip link add "veth-$i" type veth peer name veth-firewall
		sudo ip link set veth-firewall netns "$i"
		sudo ip link set "veth-$i" netns firewall
	done
}

activate_interfaces() {
	printf "\n=> Add ip addresses and activate interfaces..."
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
	printf "\n=> ####### Ping the hosts"
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

setup_routes() {
	# Add Default Gateway to clients
	sudo ip netns exec client2 ip route add default via 192.0.2.67 dev veth-firewall
	sudo ip netns exec client1 ip route add default via 192.0.2.3 dev veth-firewall

	sudo ip netns exec firewall ip route add default via 192.0.2.195 dev veth-host
	# sudo ip route add 192.0.2.0/26 via 0.0.0.0 dev veth-ns
	sudo ip route add 192.0.2.0/24 via 192.0.2.194 dev veth-ns
	#sudo ip netns exec client1 ip route add default via 192.0.3.2 dev veth-host
	#sudo ip netns exec client2 ip route add default via 192.0.3.2 dev veth-host

	sudo ip netns exec firewall sysctl -w net.ipv4.ip_forward=1

	## SETUP ROUTES
	sudo ip netns exec firewall ip route add 192.0.2.0/26 via 0.0.0.0 dev veth-client1
	sudo ip netns exec firewall ip route add 192.0.2.64/26 via 0.0.0.0 dev veth-client2
	sudo ip netns exec firewall ip route add 192.0.2.128/26 via 0.0.0.0 dev veth-server

	sudo ip netns exec server ip route add 192.0.2.0/26 via 192.0.2.131 dev veth-firewall
	sudo ip netns exec server ip route add 192.0.2.64/26 via 192.0.2.331 dev veth-firewall
}

reset_firewall() {
	sudo ip netns exec firewall iptables -P INPUT ACCEPT
	sudo ip netns exec firewall iptables -P OUTPUT ACCEPT
	sudo ip netns exec firewall iptables -P FORWARD ACCEPT

	sudo ip netns exec firewall iptables -F 
}

examine_ipaddr() {
	echo "################# EXAMINE IPADDR ######################################"
	echo "########### MAIN"
	sudo ip addr
	echo "########### FIREWALL"
	sudo ip netns exec firewall ip addr
	echo "########### CLIENT1"
	sudo ip netns exec client1 ip addr
	echo "########### CLIENT2"
	sudo ip netns exec client2 ip addr
	echo "########### SERVER"
	sudo ip netns exec server ip addr
	echo "######################################"

}

setup_firewall() {
	# Accepted states
	sudo ip netns exec firewall iptables -A INPUT -p icmp -s 192.0.2.66/26 -j ACCEPT  	# client2 can ping the firewall
	sudo ip netns exec firewall iptables -A FORWARD -p icmp -s 192.0.2.2/26 -j ACCEPT	# client1 can ping server through firewall
	sudo ip netns exec firewall iptables -A FORWARD -p tcp -s 192.0.2.66/26 -j ACCEPT 	# client2 can make HTTP request through firewall

	# Server should be able to respond
	sudo ip netns exec firewall iptables -A FORWARD -p icmp -s 192.0.2.130/26 -j ACCEPT	# client1 can ping server through firewall
	sudo ip netns exec firewall iptables -A FORWARD -p tcp -s 192.0.2.130/26 -j ACCEPT 	# client2 can make HTTP request through firewall

	# Rejected states
	sudo ip netns exec firewall iptables -A FORWARD -j DROP					# DENY all remaining FORWARD requests
	sudo ip netns exec firewall iptables -A INPUT -j DROP 					# DENY all remaining INPUT requests
	echo "# FIREWALL $?"
}

assert_fail() {
	if [ $? == 0 ]
	then
		printf "\nFailed"
	else
		printf "\nPassed"
	fi
}

assert_succeed() {
	if [ $? == 0 ]
	then
		printf "\nPassed"
	else
		printf "\nFailed"
	fi
}

test_firewall() {
	printf "\n############## TEST FIREWALL  #############"
	sudo ip netns exec client1 ping -c 1 192.0.2.130 -w 1 > /dev/null
	assert_succeed
	printf ": Client1 pings Server... (should ACCEPT\n"

	sudo ip netns exec client2 curl --connect-timeout 1 192.0.2.130:8000 > /dev/null
	assert_succeed
	printf ": Client2 requests HTTP page from Server... (should ACCEPT)\n"

	sudo ip netns exec client2 ping -c 1 -w 1 192.0.2.67 > /dev/null
	assert_succeed
	printf ": Client2 pings Firewall... (should ACCEPT)\n"

	sudo ip netns exec client1 ping -c 1 192.0.2.3 -w 1 > /dev/null
	assert_fail
	printf ": Client1 pings Firewall... (should REJECT)\n"

	sudo ip netns exec client1 curl 142.250.187.174


	printf "\n############## TEST FIREWALL END ##########\n"
}

# Reset the namespaces

remove_namespaces
add_namespaces

set_veth_connections
activate_interfaces
examine_ipaddr
examine_namespaces


sudo iptables --policy FORWARD ACCEPT
sudo sysctl -w net.ipv4.ip_forward=1
sudo ip link add veth-ns type veth peer name veth-host
sudo ip link set veth-host netns firewall up
sudo ip link set veth-ns up
sudo ip addr add 192.0.2.195/26 dev veth-ns
sudo ip netns exec firewall ip addr add 192.0.2.194/26 dev veth-host
# sudo iptables -I FORWARD -p icmp -s 192.0.3.3/26 -j ACCEPT
# sudo iptables -I FORWARD -p tcp -s 192.0.3.3/26 -j ACCEPT
# sudo iptables -I FORWARD -p icmp -d 192.0.3.3/26 -j ACCEPT
# sudo iptables -I FORWARD -p tcp -d 192.0.3.3/26 -j ACCEPT
sudo iptables -t nat -I POSTROUTING -s 192.0.2.0/24 -j MASQUERADE

setup_routes
test_pings

# Start the server
sudo ip netns exec server node server.js &
sleep 0.5

#reset_firewall
#setup_firewall
examine_ipaddr
test_firewall


echo ""





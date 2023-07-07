#!/bin/bash
declare -a NameSpaceArray=("client1" "client2" "server" "firewall")
declare -a FirewallConnection=("client1" "client2" "server")

examine_namespaces() {
	echo "=> Examine the network namespaces"
	for i in "${NameSpaceArray[@]}"
	do
		echo "== The network configuration of $i:"
		sudo ip netns exec "$i" ip addr show
	done
}

echo "=> Adding the network namespaces..."
for i in "${NameSpaceArray[@]}"
do
	sudo ip netns add "$i"
done

echo "=> Adding the network namespaces..."
for i in "${FirewallConnection[@]}"
do
	sudo ip link add "veth-$i" type veth peer name veth-firewall
	sudo ip link set veth-firewall netns "$i"
	sudo ip link set "veth-$i" netns firewall
done

examine_namespaces

echo "=> Add ip addresses"
counter=1

sudo ip -n firewall link set lo up
for i in "${FirewallConnection[@]}"
do
	echo "$counter"
	# sudo ip link add "veth-$i" type veth peer name veth-firewall
	sudo ip -n "$i" link set lo up
	sudo ip -n "$i" link set veth-firewall up
	sudo ip -n firewall link set "veth-$i" up
	sudo ip -n "$i" addr add 192.168.20.$counter/16 dev veth-firewall
	((counter++))
	sudo ip -n firewall addr add 192.168.20.$counter/16 dev "veth-$i"
	((counter++))
done

sudo ip netns exec firewall ping 192.168.20.4


examine_namespaces

echo "=> Activate network interfaces"



echo "=> Deleting the network namespaces..."
for i in "${NameSpaceArray[@]}"
do
	sudo ip netns del "$i"
done


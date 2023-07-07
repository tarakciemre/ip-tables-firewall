#!/bin/bash
declare -a NameSpaceArray=("client1" "client2" "server" "firewall")
declare -a FirewallConnection=("client1" "client2" "server")

echo "Adding the network namespaces..."
for i in "${NameSpaceArray[@]}"
do
	sudo ip netns add "$i"
done

echo "Adding the network namespaces..."
for i in "${FirewallConnection[@]}"
do
	sudo ip link add "veth-$i" type veth peer name veth-firewall
	sudo ip link set veth-firewall netns "$i"
	sudo ip link set "veth-$i" netns firewall
done

echo "Check if the created links are working"
for i in "${NameSpaceArray[@]}"
do
	echo "== The network configuration of $i:"
	sudo ip netns exec "$i" ip addr show
done




echo "Deleting the network namespaces..."
for i in "${NameSpaceArray[@]}"
do
	sudo ip netns del "$i"
done


# *iptables* Firewall
Setting up a network firewall using *iptables*, implemented with Linux network namespaces and veth pairs.

# Log
## 06.07.2023 - Day 1
### Goals
- [ ] Set up the basic topology connections
### Log
- Create network namespaces
- Create veth pairs 
- Assign veth pairs to the network namespaces
- Assign IP addresses to veth interfaces
### Notes
- Network namespace creation: `ip netns add <netns_name>`
- veth pair creation: `ip netns add <netns_name>`
- Executing a command in network namespace: `sudo ip netns exec <netns_name> <command>`
- Assigning namespace to veth: `sudo ip netns exec <netns> ip link set <veth_name> netns <netns_name>`
- Assigning IP address: `sudo ip netns exec <netns> ip addr add <ip> dev <veth_dev>`



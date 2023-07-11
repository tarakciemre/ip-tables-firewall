# *iptables* Firewall
Setting up a network firewall using *iptables*, implemented with Linux network namespaces and veth pairs.

# Log
## 06.07.2023 - Day 1
### Goals
- [x] Set up the basic topology connections
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
## 07.07.2023 - Day 2
### Goals
- [x] Add pings that test whether there is connectivity between each namespace as intended 
- [x] Add routes to clients, firewall and server according to expected behaviour
### Log
- Client1 and Client2 have default gateways routing to the firewall. 
- The server has a route to firewall so that it can send responses.
- In the firewall, the routes do not require explicit gateway configuration as the incoming packets can reach the destination from here. Gateways of 0.0.0.0 are enough.
### Notes
- Started to configure iptables as well, currently reading documentation and watching videos on it before implementing it.
## 10.07.2023 - Day 3
### Goals
- [x] Setup of the route hopping to enable requests through firewall
- [x] Clients should be able to make request to server through firewall through static routing 
- [-] Configure *iptables* in *firewall* namespace 
	- Started configuration, will continue
### Log
- Complete next hop routing of the topology except for remote connections
### Notes
## 11.07.2023 - Day 4
### Goals
- [x] Configure *iptables* in *firewall* namespace (Communications among namespaces and firewall controls for them)
- [x] Add firewall tests to check its behaviour through iterations instead of testing pings and requests by hand each time.
- [-] Set up the firewall so that it can access the internet
	- The packets are not forwarded to the internet, probably a NAT problem. Will work on this.
### Log
- Configured iptables mainly using **INPUT** and **FORWARD** chains.
	- Rules added to the **FORWARD** chain of firewall network namespace decide if a request from client should reach the server through the firewall. This was used with *icmp* protocol to control pings, and *tcp* protocol to control http requests.
	- Rules added to the **INPUT** network namespace decide what happens to packets that are destined to firewall itself. Pinging of firewall was controlled using INPUT chain.
- Tests using pings between the network namespaces were used to see if there are connectivity issues in each iteration. 
- Created a new branch called *internet-access* to test my remote network configurations.

### Notes
- The forwarding of namespace traffic to remote networks is probably problematic due to a problem in NAT or the innate firewall rules of my system. I will test if it is due to firewall by tracing the packets.
- The tests were helpful in determining when a new change broke an old functionality. That helped prevent problems a few times.

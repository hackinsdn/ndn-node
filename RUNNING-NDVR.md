# Running NDN Node with NDVR

NDVR (NDN Distance Vector Routing) is a routing protocol based on Distance Vector algorithm. The steps below shows how to run the NDN Node with NDVR propagating NDN prefixes and reachability information.

1. First step will be create the infrastructure/topology. In the example below we will use a Linear Topology with three nodes (n1, n2, n3), plus one extra (n0) node which will act as a NDN Certificate Manager to help bootstrap NDN security.

```
docker rm -f n0 n1 n2 n3
docker run -d --name n0 --privileged hackinsdn/ndn:latest sleep infinity
docker run -d --name n1 --privileged hackinsdn/ndn:latest sleep infinity
docker run -d --name n2 --privileged hackinsdn/ndn:latest sleep infinity
docker run -d --name n3 --privileged hackinsdn/ndn:latest sleep infinity
N0=$(docker exec n0 ip addr show dev eth0 | egrep -o "inet [^/]+" | cut -d" " -f2)
N1=$(docker exec n1 ip addr show dev eth0 | egrep -o "inet [^/]+" | cut -d" " -f2)
N2=$(docker exec n2 ip addr show dev eth0 | egrep -o "inet [^/]+" | cut -d" " -f2)
N3=$(docker exec n3 ip addr show dev eth0 | egrep -o "inet [^/]+" | cut -d" " -f2)
docker exec -it n1 ip link add n1-eth0 type vxlan id 1 remote $N2 dstport 8472 nolearning
docker exec -it n2 ip link add n2-eth0 type vxlan id 1 remote $N1 dstport 8472 nolearning
docker exec -it n2 ip link add n2-eth1 type vxlan id 2 remote $N3 dstport 8472 nolearning
docker exec -it n3 ip link add n3-eth0 type vxlan id 2 remote $N2 dstport 8472 nolearning
docker exec -it n1 ip link set up n1-eth0
docker exec -it n2 ip link set up n2-eth0
docker exec -it n2 ip link set up n2-eth1
docker exec -it n3 ip link set up n3-eth0
docker exec -it n1 ip addr add 10.0.1.1/30 dev n1-eth0
docker exec -it n2 ip addr add 10.0.1.2/30 dev n2-eth0
docker exec -it n2 ip addr add 10.0.1.5/30 dev n2-eth1
docker exec -it n3 ip addr add 10.0.1.6/30 dev n3-eth0
docker exec -it n1 ip route add 10.0.1.4/30 via 10.0.1.2
docker exec -it n3 ip route add 10.0.1.0/30 via 10.0.1.5
docker exec -it n1 ping -c4 10.0.1.2
docker exec -it n1 ping -c4 10.0.1.5
docker exec -it n1 ping -c4 10.0.1.6
```

2. The second step will be require starting up the daemons for NDN (i.e, NFD and NDVR):
```
docker exec n0 bash -c "ndn-cert-mgr.py >/tmp/ndn-cert-mgr.log 2>&1 & true"
for node in n1 n2 n3; do docker exec $node start-nfd.sh $node; done
for node in n1 n2 n3; do docker exec $node start-ndvr.sh $node http://$N0:3000; done
```

3. Then we recommend wait a few seconds for routing convergency (i.e, all routers exchange reachability information and synchronize their database)
```
echo "waiting for ndvr convergence"
sleep 20
```

4. List the routes learned on each router:
```
for node in n1 n2 n3; do echo "==> $node"; docker exec -it $node nfdc route list | grep -v " cost=0 "; done
```

5. Run a NDN Ping test to make sure connectivity is fine:
```
docker exec n1 bash -c "ndnpingserver /ndn/n1-site/pingserver >/tmp/ndnpingserver.log 2>&1 & true"
docker exec -it n3 ndnping -c 4 /ndn/n1-site/pingserver
```

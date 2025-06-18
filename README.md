# NDN-Node

Named Data Networking (NDN) is a future Internet architecture that shifts the focus from where data is located to what the data is, using names instead of IP addresses to identify and retrieve information.

This repo contains a docker image for building a NDN Node (i.e, a Linux docker image with NDN stack) including some tools like:
 - NFD: foundation of the NDN Stack providing the NDN forwarding capability
 - Routing protocols: NDVR and NLSR
 - Tools: ndn-ping, ndn-traffic-generator, etc
 - Troubleshooting tools: tshark to capture and visualize network traffic

Please refer to the documentation on [how to run the NDN Node with NDVR](RUNNING-NDVR.md) or [NLSR](RUNNING-NLSR.md).

The main use case for the NDN Node is the integration with [Mininet-Sec](https://mininet-sec.github.io) and the [HackInSDN experimentation platform](https://hackinsdn.ufba.br).

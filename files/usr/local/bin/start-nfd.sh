#!/bin/bash

NODE=$1

if [ -z "$NODE" ]; then
	echo "USAGE: $0 <NODENAME>"
fi

homeDir=/tmp/ndn/$NODE
logLevel=DEBUG
csSize=65536
csPolicy=lru
csUnsolicitedPolicy=drop-all
logFile=$homeDir/nfd.log
sockFile=/run/$NODE.sock
ndnFolder=/etc/ndn
confFile=$ndnFolder/nfd.conf
clientConf=$ndnFolder/client.conf

echo $(date) "Start setup NFD"

# Make sure folders exists
mkdir -p $ndnFolder
mkdir -p $homeDir

# Copy nfd.conf file from /usr/local/etc/ndn or /etc/ndn to the node's home directory
cp -f /etc/ndn/nfd.conf.sample $confFile

# Set log level
infoedit -f $confFile -s log.default_level -v $logLevel
# Open the conf file and change socket file name
infoedit -f $confFile -s face_system.unix.path -v $sockFile

# Set CS parameters
infoedit -f $confFile -s tables.cs_max_packets -v $csSize
infoedit -f $confFile -s tables.cs_policy -v $csPolicy
infoedit -f $confFile -s tables.cs_unsolicited_policy -v $csUnsolicitedPolicy

# Copy client configuration to host
cp -f /etc/ndn/client.conf.sample $clientConf

# Change the unix socket
sed -i "s|;transport|transport|g" $clientConf
sed -i "s|nfd.sock|$NODE.sock|g" $clientConf

# Generate key and install cert for /localhost/operator to be used by NFD
ndnsec-key-gen /localhost/operator | ndnsec-cert-install -

nfd --config $confFile >$logFile 2>&1 &

echo $(date) "finished setup NFD"

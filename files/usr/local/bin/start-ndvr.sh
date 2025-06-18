#!/bin/bash

if [ $# -lt 2 ]; then
	echo "USAGE: $0 <NODENAME> <CERT_MANAGER_URL>"
fi

NODE=$1
CERT_MGR=$2

test -z "$INTERVAL" && INTERVAL=1
test -z "$NETWORK"  && NETWORK=/ndn
test -z "$PREFIXES" && PREFIXES=$NETWORK/$NODE-site

homeDir=/tmp/ndn/$NODE
logLevel=DEBUG
logFile=$homeDir/ndvr.log
validationConfFile=$homeDir/ndvr-validation.conf
rootCertFile=$homeDir/ndvr-root.cert
NDVR_BIN=/usr/local/bin/ndvrd
routerId=/%C1.Router/$NODE
routerName=$NETWORK$routerId

echo $(date) "Start setup NDVR"

mkdir -p $homeDir

cp -f /etc/ndn/ndvr-validation.conf $validationConfFile

curl -s -H 'Content-type: application/json' -X POST $CERT_MGR/gen-cert -d '{"sig": "'$NETWORK'", "sub": "'$routerName'", "pw": "changeme"}' -o $homeDir/bundle.tar

tar -xf $homeDir/bundle.tar -C $homeDir/

cp $homeDir/sig.pem $homeDir/trust.cert

ndnsec-delete $routerName >/dev/null 2>&1
ndnsec-import -P changeme $homeDir/sub.pem
#ndnsec-cert-install -f $homeDir/$NODE.crt
ndnsec-set-default $routerName

FACES=$(nfdc face list remote "ether://[01:00:5e:00:17:aa]" | egrep -o "^faceid=[0-9]+" | cut -d'=' -f2)
FACE_IDS=$(for FACEID in $FACES; do echo -n "-f $FACEID "; done)

env NDN_LOG="ndvr.*=$logLevel" $NDVR_BIN -n $NETWORK -r $routerId -i $INTERVAL -v $validationConfFile $FACE_IDS -p $PREFIXES >$logFile 2>&1 &

echo $(date) "Finished setting up NDVR"

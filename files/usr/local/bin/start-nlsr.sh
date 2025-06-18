#!/bin/bash

if [ $# -lt 3 ]; then
	echo "USAGE: $0 <NODENAME> <CERT_MANAGER_URL> <NEIGHBOR> [<NEIGHBOR> ...]"
	echo ""
	echo "<NEIGHBOR>   string with neighbor name and IP, example: n1/10.0.0.1"
	echo "             you can also define the cost as 3rd param like: n1/10.0.0.1/10"
	echo "             default cost will be 10 if not defined"
	exit 0
fi

NODE=$1
CERT_MGR=$2
shift 2
NEIGHBORS=$@

test -z "$INTERVAL" && INTERVAL=1
test -z "$MAXFACES" && MAXFACES=3
test -z "$NETWORK"  && NETWORK=/ndn
test -z "$PREFIXES" && PREFIXES=$NETWORK/$NODE-site

homeDir=/tmp/ndn/$NODE
logLevel=DEBUG
logFile=$homeDir/nlsr.log
routerName="/%C1.Router/cs/$NODE"
confFile=$homeDir/nlsr.conf
security=TRUE
sync=psync
faceType=udp
infocmd="infoedit -f $confFile"
siteName=$NETWORK/$NODE-site
opName=$siteName/%C1.Operator/op
routerName=$siteName/%C1.Router/cs/$NODE

echo $(date) "Start setup NLSR"

mkdir -p $homeDir/{log,security}

### createConfigFile

cp -f /etc/ndn/nlsr.conf.sample $confFile

# general section
$infocmd -s general.network -v $NETWORK
$infocmd -s general.site -v /$NODE-site
$infocmd -s general.router -v /%C1.Router/cs/$NODE
$infocmd -s general.state-dir -v $homeDir/log
$infocmd -s general.sync-protocol -v $sync

#neighbors section
$infocmd -d neighbors.neighbor
for NEIGHBOR in $NEIGHBORS; do
	NAME=$(echo $NEIGHBOR | cut -d"/" -f1)
	IP=$(echo $NEIGHBOR | cut -d"/" -f2)
	COST=$(echo $NEIGHBOR | cut -d"/" -f3)
	test -z "$COST" && COST=10
	$infocmd -a neighbors.neighbor <<< "name $NETWORK/$NAME-site/%C1.Router/cs/$NAME face-uri $faceType://$IP link-cost $COST"
done

# hyberbolic: defaults to disable

# fib section
$infocmd -s fib.max-faces-per-prefix  -v $MAXFACES

# advertising section
$infocmd -d advertising.prefix
for PREFIX in $PREFIXES; do
	$infocmd -s advertising.prefix -v $PREFIX
done

# security (enabled by default)
$infocmd -d security.cert-to-publish
$infocmd -s security.validator.trust-anchor.file-name -v security/root.cert
$infocmd -s security.prefix-update-validator.trust-anchor.file-name -v security/site.cert
$infocmd -p security.cert-to-publish -v security/site.cert
$infocmd -p security.cert-to-publish -v security/op.cert
$infocmd -p security.cert-to-publish -v security/router.cert


### createKeysAndCertificates
# 1:
#   signer: /ndn
#   subject: /ndn
# 2:
#   signer: /ndn
#   subject: /ndn/n1-site
# 3:
#   signer: /ndn/n1-site
#   subject: /ndn/n1-site/%C1.Operator/op
# 4:
#   signer: /ndn/n1-site/%C1.Operator/op
#   subject: /ndn/n1-site/%C1.Router/cs/n1
#
# 1 and 2:
curl -s -H 'Content-type: application/json' -X POST $CERT_MGR/gen-cert -d '{"sig": "'$NETWORK'", "sub": "'$siteName'", "pw": "changeme"}' -o $homeDir/bundle.tar
tar -xf $homeDir/bundle.tar -C $homeDir/security/
mv $homeDir/security/sig.pem $homeDir/security/root.cert
ndnsec-delete $siteName >/dev/null 2>&1
ndnsec-import -P changeme $homeDir/security/sub.pem

# 3:
#   signer: /ndn/n1-site
#   subject: /ndn/n1-site/%C1.Operator/op
curl -s -H 'Content-type: application/json' -X POST $CERT_MGR/gen-cert -d '{"sig": "'$siteName'", "sub": "'$opName'", "pw": "changeme"}' -o $homeDir/bundle.tar
tar -xf $homeDir/bundle.tar -C $homeDir/security/
mv $homeDir/security/sig.pem $homeDir/security/site.cert
ndnsec-delete $opName >/dev/null 2>&1
ndnsec-import -P changeme $homeDir/security/sub.pem

# 4:
#   signer: /ndn/n1-site/%C1.Operator/op
#   subject: /ndn/n1-site/%C1.Router/cs/n1
curl -s -H 'Content-type: application/json' -X POST $CERT_MGR/gen-cert -d '{"sig": "'$opName'", "sub": "'$routerName'", "pw": "changeme"}' -o $homeDir/bundle.tar
tar -xf $homeDir/bundle.tar -C $homeDir/security/
mv $homeDir/security/sig.pem $homeDir/security/op.cert
ndnsec-delete $routerName >/dev/null 2>&1
ndnsec-import -P changeme $homeDir/security/sub.pem
ndnsec-cert-dump -i $routerName > $homeDir/security/router.cert

### End createKeysAndCertificates

### createFaces
for NEIGHBOR in $NEIGHBORS; do
	NAME=$(echo $NEIGHBOR | cut -d"/" -f1)
	IP=$(echo $NEIGHBOR | cut -d"/" -f2)
	nfdc face create $faceType://$IP permanent
done


env NDN_LOG="nlsr.*=$logLevel" nlsr -f $confFile >$logFile 2>&1 &

echo $(date) "Finished setting up NLSR"

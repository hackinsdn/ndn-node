FROM ubuntu:20.04

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    	git ca-certificates sudo curl mawk dstat procps iproute2 tshark \
	net-tools iputils-ping socat jq tcpdump bridge-utils python3-flask \
	build-essential libboost-atomic-dev libboost-chrono-dev libboost-date-time-dev \
	libboost-filesystem-dev libboost-iostreams-dev libboost-log-dev \
	libboost-program-options-dev libboost-regex-dev libboost-stacktrace-dev \
	libboost-system-dev libboost-thread-dev libpcap-dev libsqlite3-dev libssl-dev \
	libsystemd-dev pkg-config python-is-python3 python3-pip software-properties-common \
	libigraph0-dev protobuf-compiler libprotobuf-dev \
 && add-apt-repository -y -u ppa:named-data/ppa \
 && apt-get install -y --no-install-recommends \
	libndn-cxx-dev nfd libpsync-dev libchronosync-dev ndn-traffic-generator \
 && rm -rf /var/lib/apt/lists/*

RUN --mount=source=./patches,target=/mnt,type=bind \
    git clone https://github.com/italovalcy/ndvr /home/ndvr \
 && cd /home/ndvr \
 && git checkout ndvr-emu \
 && patch -p1 < /mnt/ndvr.patch \
 && ./waf configure --debug \
 && ./waf install \
 && cp config/validation.conf /etc/ndn/ndvr-validation.conf \
 && cp minindn/get-cpu-usage.sh /usr/local/bin/ \
 && cd /tmp \
 && git clone --branch ndn-tools-22.12 https://github.com/named-data/ndn-tools \
 && cd ndn-tools \
 && patch -p1 < /home/ndvr/minindn/ndn-tools-22.12-ndn-ping-variable-bit-rate.patch \
 && ./waf configure --prefix=/usr \
 && ./waf install \
 && cd /tmp \
 && git clone --branch NLSR-0.7.0 https://github.com/named-data/NLSR \
 && cd NLSR/ \
 && patch -p1 < /home/ndvr/minindn/adjustments-nlsr.patch \
 && ./waf configure --bindir=/usr/bin --sysconfdir=/etc \
 && ./waf install \
 && cd /tmp \
 && git clone https://github.com/NDN-Routing/infoedit \
 && cd infoedit/ \
 && git checkout 3226bdce4a225328df177840280f76ec81091176 \
 && make \
 && make install \
 && rm -rf /tmp/*

COPY files/ /

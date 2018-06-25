#!/bin/bash
echo begin initiating netdata ...

cd /home/vagrant
yum install -y -q zlib-devel gcc make git autoconf autogen automake pkgconfig psmisc libuuid-devel
rm -rf netdata
git clone --quiet https://github.com/firehol/netdata.git --depth=1
cd netdata
./netdata-installer.sh
echo netdata initiation end.

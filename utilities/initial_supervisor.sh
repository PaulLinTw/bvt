#!/bin/bash
echo begin initiating supervisor ...

echo installing easy_install
yum -y install python-setuptools python-setuptools-devel

echo installing supervisor
easy_install supervisor

echo copy config to /etc
cp /home/vagrant/share/supervisord.conf /etc/

echo supervisor initiation end.

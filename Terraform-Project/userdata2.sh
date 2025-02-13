#!/bin/bash

########################################################
##### USE THIS FILE IF YOU LAUNCHED AMAZON LINUX 2 #####
########################################################

# get admin privileges
sudo su


# install httpd (Linux 2 version)
yum update -y
yum install -y httpd.x86_64
systemctl start httpd.service
systemctl enable httpd.service
echo "<p>Hello World from Reesa, this is my second Insatnce  $(hostname -f)</p> <h1>This is my application</h1>" > /var/www/html/index.html

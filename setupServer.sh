#!/bin/bash

# get path to where this script (and the other ZipZap files) are located
SRC="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

# install dependencies
echo "*** BEGINNING ZIPZAP VM SETUP ***"
echo ""
echo "# Installing packages..."
apt update -y -qq
apt install -y build-essential net-tools nginx python3 python3-dev python3-pip unbound -qq

# disable resolved
echo ""
echo "# Disabling Ubuntu DNS manager..."
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved
rm -f /etc/resolv.conf
cat << _RESOLV_ > /etc/resolv.conf
nameserver 8.8.8.8
_RESOLV_

# set up nginx
echo ""
echo "# Setting up nginx web server in proxy mode..."
systemctl stop nginx.service
mv /etc/nginx /etc/nginx.bak
cp -r $SRC/windows/nginx_windows/nginx/conf /etc/nginx
cp -r $SRC/windows/nginx_windows/nginx/html /etc/nginx/html
sed -e 's/^.*root.*html/root \/etc\/nginx\/html/' -i.bak /etc/nginx/nginx.conf
sed -e 's/^.*root.*conf\/cert/root \/etc\/nginx\/html/' -i.bak /etc/nginx/nginx.conf
sed -e 's/^error_log.*$/error_log \/var\/log\/nginx\/error.log;/' -i.bak /etc/nginx/nginx.conf
sed -e 's/^.*access_log.*$/access_log \/var\/log\/nginx\/access.log combined;/' -i.bak /etc/nginx/nginx.conf
sed -e 's/^daemon/#daemon/' -i.bak /etc/nginx/nginx.conf
mkdir -p /var/log/nginx

# set up certificate
echo ""
echo "# Generating SSL certificate..."
cd $SRC && mkdir ssl
cd ssl
openssl genrsa -out ca.key 4096
openssl req -new -x509 -nodes -days 3650 -key ca.key -sha256 -extensions v3_ca -subj "/C=US/ST=NA/L=NA/O=NA/CN=*.magica-us.com" -out ca.crt
openssl req -config $SRC/site.conf -new -newkey rsa:4096 -nodes -keyout site.key -days 730 -subj "/C=US/ST=NA/L=NA/O=NA/CN=*.magica-us.com" -out site.req
openssl x509 -sha256 -req -in site.req -CA ca.crt -CAkey ca.key -CAcreateserial -out site.crt -days 730 -extensions req_extensions -extensions cert_extensions -extfile $SRC/site.conf

# install cert
echo ""
echo "# Installing SSL certificate and starting up nginx..."
mkdir -p /etc/nginx/cert /etc/nginx/html
cp ca.crt /etc/nginx/html
for FILE in site.crt site.key; do
  cp "$FILE" /etc/nginx/cert/
done
# start nginx
systemctl start nginx.service

# install dependencies etc
echo ""
echo "# Installing ZipZap python dependencies..."
cd $SRC && pip3 install -r requirements.txt

# enable rc.local
echo ""
echo "# Enabling ZipZap autostart at boot..."
cat << _RCLOCAL_ > /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
_RCLOCAL_
cat << _RCLOCAL2_ > /etc/rc.local
#!/bin/bash
cd $SRC && ./startServer.sh &
exit 0
_RCLOCAL2_
chmod +x /etc/rc.local
systemctl enable rc-local

# start it up
echo ""
echo "# Starting ZipZap..."
cd $SRC && ./startServer.sh &

echo ""
echo "*** ALL DONE! ***"
echo ""
sh /etc/rc.local > /tmp/local 2>&1
i=`$SRC/getipaddress.sh`
echo "This VM's public IP is: $i"
echo "Set your device/emulator's DNS to that address."
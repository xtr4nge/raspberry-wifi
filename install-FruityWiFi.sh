#!/bin/bash

# CONFIG
version="2.4.2"
# --------------------------------------------------------
# Setup PHP version -> options: PHP5 | PHP7
# The chosen version needs to be in the repository
# --------------------------------------------------------
#fruitywifi_php_version="PHP7"
php_version="7.3"
# --------------------------------------------------------
# Setup log path. default=/usr/share/fruitywifi/logs
# --------------------------------------------------------
fruitywifi_log_path="/usr/share/fruitywifi/logs"
# --------------------------------------------------------
# --------------------------------------------------------
# FruityWiFi set defaults [init.d]
# --------------------------------------------------------
fruitywifi_init_defaults="onboot"
# --------------------------------------------------------

find FruityWiFi -type d -exec chmod 755 {} \;
find FruityWiFi -type f -exec chmod 644 {} \;

root_path=`pwd`

mkdir tmp-install
cd tmp-install

apt-get update

echo "--------------------------------"
echo "Creates user fruitywifi"
echo "--------------------------------"
adduser --disabled-password --quiet --system --home /var/run/fruitywifi --no-create-home --gecos "FruityWiFi" --group fruitywifi
usermod -a -G inet fruitywifi # *****ERROR?!*****

echo "[fruitywifi user has been created]"
echo

apt-get -y install gettext make intltool build-essential automake autoconf uuid uuid-dev dos2unix curl sudo unzip lsb-release python-scapy tcpdump python-netifaces python-pip git ntp

pip install netifaces

#cmd=`gcc --version|grep "4.7"`
#if [[ $cmd == "" ]]
#then
#    echo "--------------------------------"
#    echo "Installing gcc 4.7" 
#    echo "--------------------------------"
	
#    apt-get -y install gcc-4.7
#    apt-get -y install g++-4.7
#    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 40 --slave /usr/bin/g++ g++ /usr/bin/g++-4.7
    
#    echo "[gcc setup completed]"

#else
#    echo "--------------------------------"
#    echo "gcc 4.7 already installed"
#    echo "--------------------------------"
#    echo
#fi

echo

if [ ! -f "/usr/sbin/dnsmasq" ]
then
    echo "--------------------------------"
    echo "Installing dnsmasq"
    echo "--------------------------------"
	
    # INSTALL DNSMASQ
    apt-get -y install dnsmasq
    
    echo "[dnsmasq setup completed]"

else
    echo "--------------------------------"
    echo "dnsmasq already installed"
    echo "--------------------------------"
    echo
fi

echo

if [ ! -f "/usr/sbin/hostapd" ]
then
    echo "--------------------------------"
    echo "Installing hostapd"
    echo "--------------------------------"

    # INSTALL HOSTAPD
    apt-get -y install hostapd
    
    echo "[hostapd setup completed]"

else
    echo "--------------------------------"
    echo "hostapd already installed"
    echo "--------------------------------"
    echo
fi

echo

if [ ! -f "/usr/sbin/airmon-ng" ] &&  [ ! -f "/usr/local/sbin/airmon-ng" ]
then
    echo "--------------------------------"
    echo "Installing aircrack-ng"
    echo "--------------------------------"

    # INSTALL AIRCRACK-NG
    apt-get -y install libssl-dev wireless-tools iw
    # DEPENDENCIES FROM AIRCRACK INSTALLER
    apt-get -y install build-essential autoconf automake libtool pkg-config libnl-3-dev libnl-genl-3-dev libssl-dev ethtool shtool rfkill zlib1g-dev libpcap-dev libsqlite3-dev libpcre3-dev libhwloc-dev libcmocka-dev
	#VERSION="aircrack-ng-1.2-beta1" # [OLD_VERSION]
	#VERSION="aircrack-ng-1.2-rc4"
    VERSION="aircrack-ng-1.5.2"
    wget http://download.aircrack-ng.org/$VERSION.tar.gz
    tar -zxvf $VERSION.tar.gz
    cd $VERSION
    autoreconf -i
    ./configure
    make
    make install
    ldconfig
    #ln -s /usr/local/sbin/airmon-ng /usr/sbin/airmon-ng
    #ln -s /usr/local/sbin/airbase-ng /usr/sbin/airbase-ng
    cd ../
    
    echo "[aircrack-ng setup completed]"

else
    echo "--------------------------------"
    echo "aircrack-ng already installed"
    echo "--------------------------------"
    echo
fi

echo

# BACK TO ROOT-INSTALL FOLDER
cd $root_path

echo "--------------------------------"
echo "Installing Nginx"
echo "--------------------------------"

# NGINX INSTALL
apt-get -y install nginx
#apt-get -y install nginx php5-fpm
echo

# SSL
echo "--------------------------------"
echo "Create Nginx ssl certificate"
echo "--------------------------------"
cd $root_path
mkdir /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt

# REMOVE DEFAULT SITE
rm /etc/nginx/sites-enabled/default

# SETUP NGINX AND PHP5|PHP7
cp nginx-setup/nginx.conf /etc/nginx/


# INSTALL PHP GENERAL
apt-get -y install php-fpm php-curl php-cli php-xml

cp nginx-setup/FruityWiFi /etc/nginx/sites-enabled/
cp nginx-setup/fpm/8000.conf /etc/php/$php_version/fpm/pool.d/
cp nginx-setup/fpm/8443.conf /etc/php/$php_version/fpm/pool.d/

# RESTART NGINX + PHP7-FPM
/etc/init.d/nginx restart
/etc/init.d/php$php_version-fpm restart

echo "[nginx setup completed]"
echo

DIR="/usr/share/fruitywifi"
if [ -d "$DIR" ]; then
	echo "--------------------------------"
	echo "BACKUP CORE AND MODULES"
	echo "--------------------------------"
	cmd=`date +"%Y-%m-%d-%H-%M-%S"`
	mv $DIR fruitywifi.BAK.$cmd	
	echo
fi

echo "--------------------------------"
echo "Setup FruityWiFi"
echo "--------------------------------"
cd $root_path
echo

echo "--------------------------------"
echo "Config log path"
echo "--------------------------------"

EXEC="s,^\$log_path=.*,\$log_path=\""$fruitywifi_log_path"\";,g"
sed -i "$EXEC" FruityWiFi/www/config/config.php
EXEC="s,^log-facility=.*,log-facility="$fruitywifi_log_path"/dnsmasq.log,g"
sed -i "$EXEC" FruityWiFi/conf/dnsmasq.conf
EXEC="s,^dhcp-leasefile=.*,dhcp-leasefile="$fruitywifi_log_path"/dhcp.leases,g"
sed -i "$EXEC" FruityWiFi/conf/dnsmasq.conf
EXEC="s,^Defaults:fruitywifi logfile =.*,Defaults:fruitywifi logfile = "$fruitywifi_log_path"/sudo.log,g"
sed -i "$EXEC" sudo-setup/fruitywifi

echo "[logs setup completed]"
echo

echo "--------------------------------"
echo "Setup Sudo"
echo "--------------------------------"
cd $root_path
cp -a sudo-setup/fruitywifi /etc/sudoers.d/
chown root:root /etc/sudoers.d/fruitywifi

echo "[sudo setup completed]"
echo

#cmd=`lsb_release -c |grep -iEe "jessie|kali|sana"`
#if [[ ! -z $cmd ]]
#then
#    echo "--------------------------------"
#    echo "Setup DNSMASQ"
#    echo "--------------------------------"
	
#    EXEC="s,^server=,#server=,g"
#    sed -i $EXEC FruityWiFi/conf/dnsmasq.conf
    
#    echo "[dnsmasq setup completed]"
#    echo

#fi

cp -a FruityWiFi /usr/share/fruitywifi
#mkdir $fruitywifi_log_path
ln -s $fruitywifi_log_path /usr/share/fruitywifi/www/logs

echo

# START/STOP SERVICES
if [[ $fruitywifi_init_defaults == "onboot" ]]
then
	echo "--------------------------------"
	echo "START SERVICES"
	echo "--------------------------------"
	
	update-rc.d ssh defaults
	update-rc.d nginx defaults
	update-rc.d ntp defaults
	
	/etc/init.d/nginx restart
    update-rc.d php$php_version-fpm defaults
    /etc/init.d/php$php_version-fpm restart

fi

#apt-get -y remove ifplugd # *****RPI CONFLICT IF NOT REMOVED/UNINSTALLED?*****

echo
echo "---------------------------"
echo "WEB-INTERFACE"
echo "---------------------------"
echo "http://localhost:8000 [http]"
echo "https://localhost:8443 [https]"
echo "user: admin"
echo "pass: admin"
echo
echo "GitHub: https://github.com/xtr4nge/FruityWifi"
echo "Twitter: @xtr4nge, @FruityWifi"
echo "ENJOY!"
echo ""

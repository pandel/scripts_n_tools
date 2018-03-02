#!/bin/bash

DEBUG=yes # set to no to let the magic happen....

# ----------------------------------------------------------------------------------------------------------------------------------
# -------------------------------------- WICHTIG !!! LESEN !!!----------------------------------------------------------------------
#
# Ablauf:
# -------
# 1.) BananaPi SD Karte mit armbian-*.img beschreiben (Win32DiskImager)
# 2.) BananaPi booten, Script per WinSCP nach /root kopieren
# 3.) mit root/1234 einloggen und Script starten
# 4.) es laufen folgende Phasen ab:
#      a) pre-Setup
#      b) REBOOT
#      c) Script ERNEUT starten, es geht weiter ;-)
#           - Phase 1: Betriebssystemvorbereitung
#           - Phase 2: opsi Installation
#
# Wichtige Meldung sind farblich markiert:
# blau: Einzelschritt
# rot: Warnungen oder Reboot Hinweise ;-)
# violett: Meldungen mit "Aufpasscharakter" ;-), evtl. mal Enter drücken
# grün: Zur Kenntnis nehmen
#
# In diesem Script befinden sich 7 sog. Here-Dokumente:
# (näheres dazu: http://www.serverwatch.com/columns/article.php/3860446/shell-scripts-and-here-documents.htm)
#
# /etc/ntp.conf (EOT1)
# /etc/apt/apt.conf (EOT2)
# /etc/nsswitch.conf (EOT3)
# /etc/apt/sources.list (EOT4)
# /etc/opsi/backendManager/dispatch.conf.vbn (EOT5)
# /etc/opsi/opsi-product-updater.conf (EOT6)
# crontab (EOT7)
# /etc/init.d/atd (EOT8)
# /etc/init.d/gruene.led.mmc0.sh (EOT9)
#
# Diese Here-Dokumente beinhalten die kompletten, o. g. Konfigurationsdateien. Ich setze zwar im Verlauf des Scripts einige Parameter
# (siehe Abschnitt "Script Parameter"), aber es könnte ja sein, dass jemand noch mehr anpassungen vornehmen muss. Dann bitte 
# das Script durchgehen und entsprechend anpassen.
#
# -----------------------------------------------------------------------------------------------------------------------------------
# Autor: Holger Pandel, holger.pandel@googlemail.com
# -----------------------------------------------------------------------------------------------------------------------------------
# -----------------------BITTE DIE SCRIPT PARAMETER KONTROLLIEREN UND EINMAL DEN VERLAUF CHECKEN OB ER SO PASST ---------------------
# -----------------------------------------------------------------------------------------------------------------------------------

# -----------------------------------------------------------------------------------------------------------------------------------
# ---------------------------------- SCRIPT PARAMETER -------------------------------------------------------------------------------
# ----------------------------B I T T E    A N P A S S E N --------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------------------------------------------
HOSTNAME="<hostname>"
TIMESERVER="<ntp.server.opsi.local>"				# name of network wide timeserver, leave blank if none available
PROXY=""							# proxy server to use, format: http://user:password@host:port/
MODULES=yes							# fetch modules file from master opsi-configserver
MASTER=config.server.opsi.local					# dns name of opsi config server
MUSER=root							# master opsi user
NEWOPSIADMIN=opsiadm						# new opsi admin user to create
SMTPHOST=smtp.server.opsi.local					# smtp host for opsi-product-updater mails
SMTPPORT=25							# smpt port
MAILREC=technik@opsi.local					# receiver address for opsi-product-updater
SETPRODUCTUPDATER=yes						# modifies opsi-product-updater.conf, see below for details
SETCRON=yes							# sets product updater cronjob - OVERWRITES existing root crontab!!!
CRONMIN=0							# cronjob minutes
CRONHOUR=5,18,23						# cronjob hours
CRONDAYS=1-5							# cronjob days of week
REGISTERASDEPOT=yes						# opsi-setup --register-depot yes/no
# -----------------------------------------------------------------------------------------------------------------------------------

# clear the screen
clear

# ---------------------------------------------------------------------------------------
# ------------------ INITIAL STEPS ------------------------------------------------------
# ---------------------------------------------------------------------------------------

HOST=`hostname`						# hostname
PACKS='mc samba-common-bin at md5deep'		# needed packages before opsi installation

# check, if script has ever reached its end, then don't run again
if [ -f ~/setup-banana.opsi.ready ]; then
    echo -e '\033[41;1;33m !!!->Script has already run completely! You really should not start it twice! \033[0m'
    exit 0
fi

# first run? then configure BananaPi and reboot
if [ ! -f ~/setup-banana.1st ]
then
	echo -e "\033[45;1;33m !!!-> Starting PREPARATION phase \033[0m"
	
	# set hostname
	echo -e '\033[44;1;33m !!!-> Set new hostname \033[0m'
	if [ "$DEBUG" = "no" ]; then 
		/usr/bin/hostnamectl set-hostname $HOSTNAME --static
	fi
	
	# generate .vimrc
	echo -e '\033[44;1;33m !!!-> Generating .vimrc \033[0m'
	if [ "$DEBUG" = "no" ]; then 
		echo 'set nocompatible' >~/.vimrc
	fi

	# generate new ntp.conf if needed
	if [ ! -z "$TIMESERVER" ]; then
		echo -e '\033[44;1;33m !!!-> Generating new ntp.conf \033[0m'
		if [ "$DEBUG" = "no" ]; then
			rm /etc/ntp.conf
			cat <<EOT1 >> /etc/ntp.conf
# /etc/ntp.conf, configuration for ntpd; see ntp.conf(5) for help

driftfile /var/lib/ntp/ntp.drift


# Enable this if you want statistics to be logged.
#statsdir /var/log/ntpstats/

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable


# You do need to talk to an NTP server or two (or three).
server $TIMESERVER

# pool.ntp.org maps to about 1000 low-stratum NTP servers.  Your server will
# pick a different set every time it starts up.  Please consider joining the
# pool: <http://www.pool.ntp.org/join.html>
server 0.debian.pool.ntp.org iburst
server 1.debian.pool.ntp.org iburst
server 2.debian.pool.ntp.org iburst
server 3.debian.pool.ntp.org iburst


# Access control configuration; see /usr/share/doc/ntp-doc/html/accopt.html for
# details.  The web page <http://support.ntp.org/bin/view/Support/AccessRestrictions>
# might also be helpful.
#
# Note that "restrict" applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Clients from this (example!) subnet have unlimited access, but only if
# cryptographically authenticated.
#restrict 192.168.123.0 mask 255.255.255.0 notrust


# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
#broadcast 192.168.123.255

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient
EOT1
		fi
	fi

	# set APT proxy
	echo -e '\033[44;1;33m !!!-> Set APT proxy if necessary \033[0m'
	if [ ! -z "$PROXY" ]; then
		if [ "$DEBUG" = "no" ]; then
			rm /etc/apt/apt.conf
			cat <<EOT2 >> /etc/apt/apt.conf
Acquire::http::Proxy "$PROXY";
EOT2
		fi
	fi

	# install some needed packages
	if [ ! -z "$PACKS" ]; then
		echo -e '\033[44;1;33m !!!-> Install some packages \033[0m'
		if [ "$DEBUG" = "no" ]; then
			apt-get -y update
			apt-get -y install $PACKS
		fi
	fi

	# load german keys explicitly
	echo -e '\033[44;1;33m !!!-> Load de-latin1-nodeadkeys \033[0m'
	loadkeys de-latin1-nodeadkeys.kmap.gz

	echo -e '\033[44;1;33m !!!-> Language and timezone settings \033[0m'
        if [ "$DEBUG" = "no" ]; then
			dpkg-reconfigure locales
			dpkg-reconfigure console-setup
			dpkg-reconfigure console-data
			dpkg-reconfigure tzdata
	fi
	
	# finally reboot first time
	echo -e '\033[41;1;33m !!!-> After this reboot please re-run the script... \033[0m'
	if [ "$DEBUG" = "no" ]; then
		touch ~/setup-banana.1st
		reboot
		exit 0
	fi
fi

# ---------------------------------------------------------------------------------------
# ------------------ FIRST PART: BASIC BANANA SETUP -------------------------------------
# ---------------------------------------------------------------------------------------

if [ ! -f ~/setup-banana.2nd ]
then
	echo -e '\033[45;1;33m !!!-> Starting FIRST configuration part... \033[0m'
	
	
	# generate new nsswitch.conf for correct name resolution order
	echo -e '\033[44;1;33m !!!-> Generate new nsswitch.conf \033[0m'
	if [ "$DEBUG" = "no" ]; then
		rm /etc/nsswitch.conf
		cat <<EOT3 >> /etc/nsswitch.conf
# /etc/nsswitch.conf
#
# Example configuration of GNU Name Service Switch functionality.
# If you have the 'glibc-doc-reference' and 'info' packages installed, try:
# 'info libc "Name Service Switch"' for information about this file.

passwd:         compat
group:          compat
shadow:         compat

hosts:          dns files myhostname
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOT3
	fi
	
	# reconfigure green led to reflect SD card activity
	echo -e '\033[44;1;33m !!!-> Re-configure green LED \033[0m'
	if [ "$DEBUG" = "no" ]; then
		cat <<'EOT9' >> /etc/init.d/gruene.led.mmc0.sh
#! /bin/sh

### BEGIN INIT INFO
# Provides:          gruene_led
# Required-Start:    $local_fs $remote_fs
# Required-Stop:
# X-Start-Before:    rmnologin
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Reconfigures green LED for SD card activity
# Description: Reconfigures green LED for SD card activity
### END INIT INFO

. /lib/lsb/init-functions

N=/etc/init.d/sudo

set -e

case "$1" in
  start)
        echo mmc0 > /sys/class/leds/bananapi\:green\:usr/trigger
        ;;
  stop)
        echo none > /sys/class/leds/bananapi\:green\:usr/trigger
        ;;
  status)
        cat /sys/class/leds/bananapi\:green\:usr/trigger
        ;;

  *)
        echo "Usage: $N {start|stop|status}" >&2
        exit 1
        ;;
esac

exit 0
EOT9

		#touch /etc/init.d/gruene.led.mmc0.sh
		#echo  'echo mmc0 > /sys/class/leds/green\:ph24\:led1/trigger' >/etc/init.d/gruene.led.mmc0.sh
		chmod +x /etc/init.d/gruene.led.mmc0.sh
		systemctl enable gruene.led.mmc0.sh
		# activate now, too
		echo mmc0 > /sys/class/leds/bananapi\:green\:usr/trigger

		# create marker basic setup don
		touch ~/setup-banana.2nd
	fi

	# change ulimit to 30000
	echo -e '\033[44;1;33m !!!-> Change ulimit to 30000 \033[0m'
	if [ "$DEBUG" = "no" ]; then
		echo "* soft nofile 30000" >> /etc/security/limits.conf
	fi
	
	# create new startup script for atd with -b 0 option
	echo -e '\033[44;1;33m !!!-> Create new atd startup script \033[0m'
	if [ "$DEBUG" = "no" ]; then
		rm /etc/init.d/atd
		cat <<'EOT8' >> /etc/init.d/atd
#! /bin/sh
### BEGIN INIT INFO
# Provides:          atd
# Required-Start:    $syslog $time $remote_fs
# Required-Stop:     $syslog $time $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Deferred execution scheduler
# Description:       Debian init script for the atd deferred executions
#                    scheduler
### END INIT INFO
#
# Author:       Ryan Murray <rmurray@debian.org>
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin
DAEMON=/usr/sbin/atd
OPTS="-b 0"
PIDFILE=/var/run/atd.pid

test -x $DAEMON || exit 0

. /lib/lsb/init-functions

case "$1" in
  start)
        log_daemon_msg "Starting deferred execution scheduler" "atd"
        start_daemon -p $PIDFILE $DAEMON $OPTS
        log_end_msg $?
    ;;
  stop)
        log_daemon_msg "Stopping deferred execution scheduler" "atd"
        killproc -p $PIDFILE $DAEMON
        log_end_msg $?
    ;;
  force-reload|restart)
    $0 stop
    $0 start
    ;;
  status)
    status_of_proc -p $PIDFILE $DAEMON atd && exit 0 || exit $?
    ;;
  *)
    echo "Usage: /etc/init.d/atd {start|stop|restart|force-reload|status}"
    exit 1
    ;;
esac

exit 0
EOT8
		chmod 744 /etc/init.d/atd
	fi
	
fi

# just a message and a short pause
echo -n -e '\033[45;1;33m !!!-> FIRST part done, heading to opsi installation, press [ENTER] to proceed... \033[0m'
IFS= read DUM

# ---------------------------------------------------------------------------------------
# ------------------ SECOND PART: OPSI INSTALLATION -------------------------------------
# ---------------------------------------------------------------------------------------

	echo -e '\033[45;1;33m !!!-> Starting SECOND configuration part... \033[0m'

# now, install basic packages
echo -e '\033[44;1;33m !!!-> Install necessary os packages for opsi server \033[0m'
if [ "$DEBUG" = "no" ]; then
	apt-get -y install wget lsof host python-mechanize p7zip-full cabextract openbsd-inetd pigz
	apt-get -y install samba samba-common smbclient cifs-utils samba-doc
	apt-get -y install mysql-server
fi

# add wheezy packages
echo -e '\033[44;1;33m !!!-> Add Debian Jessie package source to APT \033[0m'
if [ "$DEBUG" = "no" ]; then
	cat <<EOT4 >> /etc/apt/sources.list

deb http://download.opensuse.org/repositories/home:/uibmz:/opsi:/opsi40/Debian_8.0 ./
EOT4
fi

# fetch uib packages
echo -e '\033[44;1;33m !!!-> Fetching uib GmbH Release.key \033[0m'
if [ "$DEBUG" = "no" ]; then
	export http_proxy=$PROXY
	export https_proxy=$PROXY
	wget -O - http://download.opensuse.org/repositories/home:/uibmz:/opsi:/opsi40/Debian_8.0/Release.key | apt-key add -
	export http_proxy=
	export https_proxy=
fi
echo -e '\033[41;1;33m !!!-> >>>> Please check, if key is imported correctly !!!! \033[0m'
echo -e '\033[42;1;33m'
apt-key list
echo -e '\033[0m'

echo -n -e '\033[45;1;33m Press [ENTER] to proceed... \033[0m'
IFS= read DUM


# create opsi directories
echo -e '\033[44;1;33m !!!-> Creating /home/opsiproducts \033[0m'
if [ "$DEBUG" = "no" ]; then 
	mkdir /home/opsiproducts
	mkdir /var/lib/opsi
	mkdir /var/lib/opsi/config
	mkdir /var/lib/opsi/config/audit
	mkdir /var/lib/opsi/config/clients
	mkdir /var/lib/opsi/config/depots
	mkdir /var/lib/opsi/config/products
	mkdir /var/lib/opsi/config/templates
	mkdir /var/lib/opsi/depot
	mkdir /var/lib/opsi/ntfs-images
	mkdir /var/lib/opsi/tmp
	chmod 777 /var/lib/opsi/tmp
	mkdir /tftpboot
	mkdir /tftpboot/linux
fi

# install opsi main packages
echo -e '\033[44;1;33m !!!-> Install main opsi packages \033[0m'
if [ "$DEBUG" = "no" ]; then
	apt-get -y update
	aptitude -y safe-upgrade
	update-inetd --remove tftpd
	systemctl disable winbind
	aptitude -y install opsi-depotserver-expert
	opsi-setup --set-rights
	aptitude -y install opsi-configed
fi

# get modules conf from central master via scp
if [ "$MODULES" = "yes" ]; then
	echo -e '\033[44;1;33m !!!-> Fetch modules file from master server, enter password \033[0m'
	if [ "$DEBUG" = "no" ]; then scp $MUSER@$MASTER:/etc/opsi/modules /etc/opsi/; fi
fi


# setup MySQL basic database
echo -e '\033[44;1;33m !!!-> Setup opsi database \033[0m'
if [ "$DEBUG" = "no" ]; then opsi-setup --configure-mysql; fi

# generate new dispatch.conf
echo -e '\033[44;1;33m !!!-> Generate new dispatch.conf \033[0m'
if [ "$DEBUG" = "no" ]; then
	rm /etc/opsi/backendManager/dispatch.conf.vbn
	cat <<EOT5 >> /etc/opsi/backendManager/dispatch.conf.vbn
backend_.* : file, mysql, opsipxeconfd
host_.* : file, opsipxeconfd
productOnClient_.* : file, opsipxeconfd
configState_.* : file, opsipxeconfd
license.* : mysql
softwareLicense.* : mysql
audit.* : mysql
.* : file
EOT5
	rm /etc/opsi/backendManager/dispatch.conf
	ln -s /etc/opsi/backendManager/dispatch.conf.vbn /etc/opsi/backendManager/dispatch.conf
fi

# apply settings
echo -e '\033[44;1;33m !!!-> Apply changes to opsi services \033[0m'
if [ "$DEBUG" = "no" ]; then
	opsi-setup --init-current-config
	opsi-setup --set-rights
	service opsiconfd restart
	service opsipxeconfd restart
fi

# setup environment
echo -e '\033[44;1;33m !!!-> Setting up Samba \033[0m'
if [ "$DEBUG" = "no" ]; then opsi-setup --auto-configure-samba; fi
echo -e '\033[44;1;33m !!!-> Setting Pcpatch password \033[0m'
if [ "$DEBUG" = "no" ]; then opsi-admin -d task setPcpatchPassword; fi
echo -e '\033[44;1;33m !!!-> Setting samba password \033[0m'
if [ "$DEBUG" = "no" ]; then smbpasswd -a $NEWOPSIADMIN; fi
echo -e '\033[44;1;33m !!!-> Add user to opsiadmin group \033[0m'
if [ "$DEBUG" = "no" ]; then usermod -aG opsiadmin $NEWOPSIADMIN; fi
echo -e '\033[44;1;33m !!!-> Add user to pcpatch group \033[0m'
if [ "$DEBUG" = "no" ]; then usermod -aG pcpatch $NEWOPSIADMIN; fi
echo -e '\033[44;1;33m !!!-> Patch sudoers file \033[0m'
if [ "$DEBUG" = "no" ]; then opsi-setup --patch-sudoers-file; fi

# register as depot
if [ "$REGISTERASDEPOT" = "yes" ]; then
    echo -e '\033[44;1;33m !!!-> Register as depot server \033[0m'
    if [ "$DEBUG" = "no" ]; then opsi-setup --register-depot; fi
fi

# generate new opsi-product-updater.conf
if [ "$SETPRODUCTUPDATER" = "yes" ]; then
    echo -e '\033[44;1;33m !!!-> Generating new updater configuration \033[0m'
	if [ "$DEBUG" = "no" ]; then 
		mv /etc/opsi/opsi-product-updater.conf /etc/opsi/opsi-product-updater.conf-orig
		cat <<EOT6 >> /etc/opsi/opsi-product-updater.conf
[general]
; Where to store package files
packageDir = /var/lib/opsi/repository
; Location of log file
logFile = /var/log/opsi/opsi-product-updater.log
; Log level 0...9
logLevel = 9
; set defaulttimeout
timeout = 60
; path to temp directory for package installation
; changed, because /tmp often is mounted as tmpfs and has not enought space for bigger packets
tempdir = /var/lib/opsi/tmp

[notification]
; Activate/deactivate eMail notification
active = true
; SMTP server address
smtphost = $SMTPHOST
; SMTP server port
smtpport = $SMTPPORT
; SMTP username
;smtpuser = username
; SMTP password for user
;smtppassword = s3cR3+
; Use STARTTLS
use_starttls = False
; Sender eMail address
sender = opsi-product-updater-$HOST@volksbank-niederrhein.de
; Comma separated list of receivers
receivers = $MAILREC

[installation]
; If window start AND end are set, installation of the newly downloaded packages
; will only be done if the time when all downloads are completed is inside the time window
; Times have to be speciefied in the form HH:MM, i.e. 06:30
windowStart =
windowEnd =
; Comma separated list of product ids which will be installed even outside the time window
exceptProductIds =

[wol]
; If active is set to true, wake on lan will be sent to clients which need to perform actions
active = false
; Comma separated list of product ids which will not trigger wake on lan
excludeProductIds =
; Shutdown clients after installation?
; Before you set this to true please asure that the product shutdownwanted is installed on the depot
shutdownWanted = true
; Gap in seconds between wake ups
startGap = 10

[repository_uib]
; Activate/deactivate the repository
active = false
; If the repository is an opsi depot, opsiDepotId should be set
; In that case it is not required (but allowed) to set baseUrl, dirs, username and password
opsiDepotId =
; The base url of a product package repository
baseUrl = http://download.uib.de
; Comma separated directories to include in search for product packages
; Use / if search should be done in baseUrl
dirs = opsi4.0/products/localboot, opsi4.0/products/netboot
; Comma separated list of productIds that will be updated
; If not a product package file matches one of these regular expressions it will not be downloaded
includeProductIds =
; Comma separated list of regular expressions
; If a product package file matches one of these regular expressions it will not be downloaded
excludes = ^win.*
; Username for connection to repository
username =
; Password for connection to repository
password =
; AutoInstall will be checked if a product package is found on the repository
; and the product is not yet installed on the local depot
autoInstall = false
; AutoUpdate will be checked if a product is already installed on the local depot
; and a more recent product version is found in the repository
autoUpdate = true
; If autoSetup is set to true, the action request "setup" will be set for every updated product
; on all clients of the local depot where the installation status of the product is "installed"
autoSetup = false
; Set True if you want only Download packages without installation
onlyDownload = false
; Set Proxy handler like: http://10.10.10.1:8080
proxy =

[repository_master]
active = true
opsiDepotId = $MASTER
autoInstall = true
autoUpdate = true
autoSetup = false
; Inherit ProductProperty defaults from master repository
inheritProductProperties = true
EOT6
	fi
fi

# create cronjob for automatic package update
if [ "$SETCRON" = "yes" ]; then
    echo -e '\033[44;1;33m !!!-> Generating crontab entry \033[0m'
	if [ "$DEBUG" = "no" ]; then 
		crontab <<EOT7
$CRONMIN $CRONHOUR * * $CRONDAYS /usr/bin/opsi-product-updater -vv
EOT7
	fi
fi

# master marker to not let run the script twice
if [ "$DEBUG" = "no" ]; then touch ~/setup-banana.opsi.ready; fi

echo -e '\033[42;1;33m !!!-> BananaPi opsi Server setup finished! \033[0m'
echo -e '\033[41;1;33m !!!-> Please reboot now! \033[0m'

exit 0

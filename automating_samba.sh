#!/bin/bash

# Author: omrsangx

CURRENT_DATE=$(date +%Y_%m_%d_%H_%M)
USER_SHARE="shareuser"
IP_ADDRESS_ALLOWED="192.168.5.4"
ROOT=$(whoami)
INSTALLATION_LOG="/tmp/smb_setup_$CURRENT_DATE"
OS_VERSION=$(grep -iE "^ID=" /etc/os-release | awk -F"=" '{print $2}')

# Run as root
if [ $ROOT != "root" ] ; then
    echo "$(whoami) is not a root user"
    echo "Run as root"
    echo "Terminating the script"
    exit 1    
fi

if [ ! -d /smb ] ; then
        mkdir /smb
fi

if [ $OS_VERSION == "rhel" ] || [ $OS_VERSION == "centos" ] ; then
    echo "CentOS/RHEL"
    yum update -y | tee -a $INSTALLATION_LOG
    yum install samba -y | tee -a $INSTALLATION_LOG
fi

if [ $OS_VERSION == "ubuntu" ] || [ $OS_VERSION == "debian" ] ; then
    echo "Ubuntu/Debian"
    apt update -y | tee -a $INSTALLATION_LOG
    apt install samba -y | tee -a $INSTALLATION_LOG
fi

cat << EOF > /etc/samba/smb.conf  
# See smb.conf.example for a more detailed config file or
# read the smb.conf manpage.
# Run 'testparm' to verify the config is correct after
# you modified it.

[global]
        workgroup = SAMBA
        security = user
        passdb backend = tdbsam
        printing = cups
        printcap name = cups
        load printers = yes
        cups options = raw
        protocol = SMB3
        client min protocol = SMB3
        client max protocol = SMB3 
        smb encrypt = auto
        client ntlmv2 auth = yes
        usershare allow guests = No

#[homes]
#        comment = Home Directories
#        valid users = %S, %D%w%S
#        browseable = No
#        read only = No
#        inherit acls = Yes

#[printers]
#        comment = All Printers
#        path = /var/tmp
#        printable = Yes
#        create mask = 0600
#        browseable = No

#[print$]
#       comment = Printer Drivers
#       path = /var/lib/samba/drivers
#       write list = @printadmin root
#       force group = @printadmin
#       create mask = 0664
#       directory mask = 0775

[devShare]
        comment = Samba Server
        path = /smb
        browseable = Yes
        valid users = $USER_SHARE
        read only = No
        writable = Yes
        browseable = Yes
        invalid users = root bin daemon nobody named sys tty disk mem kmem users admin guest
        hosts allow = $IP_ADDRESS_ALLOWED
        interfaces = eth0
        # deny hosts =
        # log file = /var/log/samba/log.%m
        hosts deny = ALL
        encrypt passwords = Yes
        public = No
        #guest only = No
        #guest ok = No
        inherit acls = No
        directory mask = 0755
        create mask = 0755

EOF

# useradd shareuser
sudo useradd --no-create-home --uid 2040 --shell /bin/false $USER_SHARE | tee -a $INSTALLATION_LOG
smbpasswd -a $USER_SHARE
mkdir /smb
chmod 754 /smb
sudo chown -R $USER_SHARE:$USER_SHARE /smb | tee -a $INSTALLATION_LOG

# SMB Services enable, start
sudo systemctl enable --now {smb,nmb} | tee -a $INSTALLATION_LOG
systemctl start smb | tee -a $INSTALLATION_LOG
systemctl status smb | tee -a $INSTALLATION_LOG

# SELinux Configuration
setsebool -P samba_export_all_ro=1 samba_export_all_rw=1 | tee -a $INSTALLATION_LOG

# Firewall Configuration
# iptables -I INPUT -j ACCEPT
ufw allow samba | tee -a $INSTALLATION_LOG
# sudo firewall-cmd --permanent --add-service=samba
# sudo firewall-cmd --reload

# Samba resource page:
# https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html

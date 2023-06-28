#!/bin/bash

# Author: omrsangx

ROOT=$(whoami)
DATE=$(date +%Y_%m_%d_%H_%M)
SHARE_USER="shareuser"
SHARE_NAME="devShare"
SHARE_WORKGROUP="SAMBA"
SHARE_LOCATION="/smb"
IP_ADDRESS_ALLOWED="192.168.5.4"
SMB_NETWORK_INTERFACE="eh0"
INSTALLATION_LOG="/tmp/smb_setup_$DATE"
OS_VERSION=$(grep -iE "^ID=" /etc/os-release | awk -F"=" '{print $2}')

# Run as root
if [ $ROOT != "root" ] ; then
    echo "$(whoami) is not a root user"
    echo "Run as root"
    echo "Terminating the script"
    exit 1    
fi

if [ ! -d "$SHARE_LOCATION" ] ; then
        mkdir $SHARE_LOCATION
fi

if [ $OS_VERSION == "rhel" ] || [ $OS_VERSION == "centos" ] ; then
    echo "CentOS/RHEL"
    yum update -y | tee -a $INSTALLATION_LOG
    yum install samba -y | tee -a $INSTALLATION_LOG
    # samba samba-client
fi

if [ $OS_VERSION == "ubuntu" ] || [ $OS_VERSION == "debian" ] ; then
    echo "Ubuntu/Debian"
    apt update -y | tee -a $INSTALLATION_LOG
    apt install samba -y | tee -a $INSTALLATION_LOG
fi

mv /etc/samba/smb.conf /etc/samba/smb.conf.backup_$DATE

cat << EOF > /etc/samba/smb.conf  
# See smb.conf.example for a more detailed config file or
# read the smb.conf manpage.
# Run 'testparm' to verify the config is correct after
# you modified it.
# [homes], [printers], and [print$] are commented out because I didn't need it at the moment
[global]
        workgroup = $SHARE_WORKGROUP
        security = user
        server string = samba_server
        passdb backend = tdbsam
        printing = cups
        printcap name = cups
        load printers = no
        cups options = raw
        protocol = SMB3
        client min protocol = SMB3
        client max protocol = SMB3
        client smb3 encryption algorithms = AES-128-GCM, AES-128-CCM, AES-256-GCM, AES-256-CCM 
        smb encrypt = auto
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

[$SHARE_NAME]
        comment = Samba Server
        path = $SHARE_LOCATION
        browseable = Yes
        valid users = $SHARE_USER
        read only = No
        writable = Yes
        browseable = Yes
        invalid users = root bin daemon nobody named sys tty disk mem kmem users admin guest
        hosts allow = $IP_ADDRESS_ALLOWED
        interfaces = lo $SMB_NETWORK_INTERFACE
        # deny hosts =
        log file = /var/log/samba/log.%m
        hosts deny = ALL
        encrypt passwords = Yes
        public = No
        guest only = No
        guest ok = No
        inherit acls = No
        directory mask = 0755
        create mask = 0755

EOF

# useradd shareuser
useradd --no-create-home --uid 2040 --shell /bin/false $SHARE_USER | tee -a $INSTALLATION_LOG
smbpasswd -a $SHARE_USER
chmod 774 $SHARE_LOCATION
chown -R $SHARE_USER:$SHARE_USER $SHARE_LOCATION | tee -a $INSTALLATION_LOG

setfacl -R -m "u:$SHARE_USER:rwx" $SHARE_LOCATION

# SELinux Configuration
setsebool -P samba_export_all_ro=1 samba_export_all_rw=1 | tee -a $INSTALLATION_LOG

# Firewall Configuration
#FIREWALLD=$(firewall-cmd --state)
FIREWALLD=$(systemctl is-failed firewalld)
UFW=$(ufw status | awk -F": " '{print $2}')

if [ $FIREWALLD == 'running' ] ; then 
    firewall-cmd --permanent --add-service=samba
    firewall-cmd --reload

elif [ $UFW == 'active' ] ; then 
    ufw allow samba | tee -a $INSTALLATION_LOG

else
    iptables -I INPUT -s 192.168.5.0/24 -m state --state NEW -p tcp --dport 137 -j ACCEPT
    iptables -I INPUT -s 192.168.5.0/24 -m state --state NEW -p tcp --dport 138 -j ACCEPT
    iptables -I INPUT -s 192.168.5.0/24 -m state --state NEW -p tcp --dport 139 -j ACCEPT
    iptables -I INPUT -s 192.168.5.0/24 -m state --state NEW -p tcp --dport 445 -j ACCEPT
fi

# SMB Services enable, start
if [ $OS_VERSION == "rhel" ] || [ $OS_VERSION == "centos" ] ; then
    echo "CentOS/RHEL"
    systemctl enable --now {smb,nmb} | tee -a $INSTALLATION_LOG
    systemctl start smb | tee -a $INSTALLATION_LOG
    systemctl status smb | tee -a $INSTALLATION_LOG
fi 

if [ $OS_VERSION == "ubuntu" ] || [ $OS_VERSION == "debian" ] ; then
    echo "Ubuntu/Debian"
    systemctl enable --now {smbd,nmbd} | tee -a $INSTALLATION_LOG
    systemctl start smbd | tee -a $INSTALLATION_LOG
    systemctl status smbd | tee -a $INSTALLATION_LOG
fi

# Checking if Samba is properly configured
testparm

# Samba resource page:
# https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html

# Mapping shre from Windows:
echo "You will be able to map this share in Windows using the follwoing \\$IP_ADDRESS_ALLOWED\$SHARE_NAME"


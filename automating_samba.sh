#!/bin/bash

# Author: omrsangx

# Run as root
if [ whoami != "root" ]
    echo "Run as root"
    echo "Terminating the script"

else
    funcSamba
fi

2> /tmp/automating_error.txt

funcSamba () {
    yum update -y
    yum install samba -y

    # ------> Note for the future, the smb.conf can be predefine and then copy to the server  
    # ------> CHECK /etc/smb.conf
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
        valid users = shareuser
        read only = No
        writable = Yes
        browseable = Yes
        invalid users = root bin daemon nobody named sys tty disk mem kmem users admin guest
        hosts allow = 192.168.5.4
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
    sudo useradd --no-create-home --uid 2040 --shell /bin/false shareuser
    smbpasswd -a shareuser    # ------> this need some working
    mkdir /smb
    chmod 777 /smb
    sudo chown -R user_name:user_group /smb

    # SMB Services enable, start
    sudo systemctl enable --now {smb,nmb}
    systemctl start smb
    systemctl status smb

    # SELinux Configuration
    setsebool -P samba_export_all_ro=1 samba_export_all_rw=1

    # Firewall Configuration:
    # ------> also the firewall configuration can be copied 
    # iptables -A INPUT -j ACCEPT
    # ufw allow samba
    sudo firewall-cmd --permanent --add-service=samba
    sudo firewall-cmd --reload
}

 if [ ! -d /smb ] ; then
        mkdir /smb
fi

# Samba resource page:
# https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html

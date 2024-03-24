#!/bin/bash

# Author: omrsangx

HELPER=$1

if [[ $HELPER == "-h" || $HELPER == "--help"  ]] ; then
    echo "Enter automate-jupyter-notebook.sh -h OR automate-jupyter-notebook.sh --help for more info"
    echo "Common errors: Lack of disk space"
    exit 0
fi

DATE=$(date +%Y_%m_%d_%H_%M)
INSTALLATION_LOG="/tmp/node_setup_$DATE.log"

ANACONDA_INSTALLATION_DIR="/home/$USER/anaconda3"
OS_VERSION=$(grep -iE "^ID=" /etc/os-release | grep -oE "rhel|ubuntu|amzn")
JUPYTER_NOTEBOOK_DIR="/home/$USER/jupyter-notebook"
JUPYTER_CONFIGURATION_DIR="/home/$USER/.jupyter"
JUPYTER_CERTIFICATE="/home/$USER/.jupyter/certs"
JUPYTER_NOTEBOOK_IP_ADDRESS="192.168.5.200"

echo "========> Installing required packages: argon2 and wget"
if [[ $OS_VERSION == "rhel" ]] || [[ $OS_VERSION == "centos" ]] ; then
    echo "CentOS/RHEL"
    sudo yum install argon2 wget -y | tee -a $INSTALLATION_LOG
fi

if [[ $OS_VERSION == "ubuntu" ]] || [[ $OS_VERSION == "debian" ]] ; then
    echo "Ubuntu/Debian"
    # sudo apt update -y | tee -a $INSTALLATION_LOG
    sudo apt install argon2 wget -y | tee -a $INSTALLATION_LOG
fi

if [[ $OS_VERSION == "amzn" ]] ; then
    echo "========> AmazonLinux"
    sudo yum install argon2 wget -y | tee -a $INSTALLATION_LOG
fi

echo "========> Creating the Jupyter directory"
if [ ! -d JUPYTER_NOTEBOOK_DIR ] ; then
    mkdir $JUPYTER_NOTEBOOK_DIR
fi

echo "========> Creating the Jupyter certificate directory"
if [ ! -d JUPYTER_CERTIFICATE ]; then
    mkdir -p $JUPYTER_CERTIFICATE
fi

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------

echo "========> Anaconda installation and Configuration"
# wget -O anaconda3.sh https://repo.anaconda.com/archive/Anaconda3-2021.11-Linux-x86_64.sh
wget -O anaconda3-2024.sh https://repo.anaconda.com/archive/Anaconda3-2024.02-1-Linux-x86_64.sh
bash anaconda3-2024.sh -b

# To choose a different directory:
# PREFIX=/home/anaconda-new-dir-to-install-packages
# bash anaconda3.sh -b -p $PREFIX

echo "========> Initilizing Anaconda"
echo "========> Initilizing Anaconda"

$ANACONDA_INSTALLATION_DIR/bin/conda init 

echo "Activating Anaconda"
source ~/.bashrc
                  # $ANACONDA_INSTALLATION_DIR/bin/activate  ----> not working once initialized depricated
conda activate
conda update --all --yes

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------

echo "========> Configuring Jupyter Notebook"
source ~/.bashrc
jupyter notebook --generate-config

echo "Configuring Jupyter Notebook password hash"
read -r -p "Enter a password to use with Jupyter Notebook: " JUPYTER_NOTEBOOK_PASSWORD

JUPYTER_HASH=$(echo -n "$JUPYTER_NOTEBOOK_PASSWORD" | argon2 saltItWithSalt -l 32 | grep -i "Encoded" | awk -F":" '{print $2}' | sed -e 's/^[ \t]*//')
echo "========> Password has: $JUPYTER_HASH"

cat << EOF > $JUPYTER_CONFIGURATION_DIR/jupyter_notebook_config.json
{
  "NotebookApp": {
    "password": "$JUPYTER_HASH"
  }
}
EOF

echo "========> Generating a key and self-signed certificate for Jupyter Notebook"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $JUPYTER_CERTIFICATE/jupyter_notebook.key -out $JUPYTER_CERTIFICATE/jupyter_notebook.pem

echo "========> Configuring jupyter_notebook_config.py"
IP_ADDRESSES_CONFIGURED_LIST=()
IP_ADDRESSES_CONFIGURED_LIST_MAX=12
COUNT=0

echo "The following(s) are the IPv4 addresses setup in your system:"

for IP_ADDR in $(ip ad | grep -Eo "(\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}" | grep -v "127.0.0.1\|255") ; do
    IP_ADDRESSES_CONFIGURED_LIST[COUNT]="$IP_ADDR"
    echo "$COUNT) ${IP_ADDRESSES_CONFIGURED_LIST[COUNT]}"
    COUNT=$(expr $COUNT + 1)
    if [[ $COUNT -eq $IP_ADDRESSES_CONFIGURED_LIST_MAX ]] ; then
        break
    fi
done

echo -e "\n"
read -r -p "Enter a number to choose one from 0 to $(expr $COUNT - 1): " NUMBER_ENTERED

# while $NUMBER_ENTERED is empty or not a number or greater than $COUNT -1
while [[ -z $NUMBER_ENTERED ]] || [[ ! $NUMBER_ENTERED =~ ^[0-9]+$ ]] || [[ $NUMBER_ENTERED -gt $(expr $COUNT - 1) ]] ; do
        echo "You have entered an invalid number."
        read -r -p "Enter a number to choose one from 0 to $(expr $COUNT - 1): " NUMBER_ENTERED
done

echo "you selected ${IP_ADDRESSES_CONFIGURED_LIST[$NUMBER_ENTERED]}"
JUPYTER_NOTEBOOK_IP_ADDRESS=${IP_ADDRESSES_CONFIGURED_LIST[$NUMBER_ENTERED]}
echo -e "\n"
read -r -p "Enter the port number for Jupyter Notebook to use: " JYPTER_NOTEBOOK_PORT

echo "========> Backing up Jupyter's default configuration file"
mv  $JUPYTER_CONFIGURATION_DIR/jupyter_notebook_config.py ~/.jupyter/jupyter_notebook_config.py.backup

cat << EOL >  $JUPYTER_CONFIGURATION_DIR/jupyter_notebook_config.py
c.NotebookApp.certfile = u'$JUPYTER_CERTIFICATE/jupyter_notebook.pem'
c.NotebookApp.keyfile = u'$JUPYTER_CERTIFICATE/jupyter_notebook.key'
c.NotebookApp.port = $JYPTER_NOTEBOOK_PORT
c.NotebookApp.open_browser = False
c.NotebookApp.ip = '$JUPYTER_NOTEBOOK_IP_ADDRESS'

EOL

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------

echo "========> Configuring the firewall"
# firewall-cmd --permanent --zone=public --add-port=8989/tcp
# firewall-cmd --reload
# firewall-cmd --permanent --zone=public --list-ports

echo "Adding the $JYPTER_NOTEBOOK_PORT port to the firewall rule to allow incoming traffic."
echo -e "\n"

echo "Configuring the firewall. This requires root access"
echo -e "\n"

echo "Firewall options. If there is not any firewall setup in your system, enter 3:"
echo "0) iptables"
echo "1) Firewalld"
echo "2) UFW"
echo "3) Skip firewall configuration"

read -r -p "Enter a number to choose one from 0 to 3: " FIREWALL_VALUE_ENTERED

while [[ -z $FIREWALL_VALUE_ENTERED ]] || [[ ! $FIREWALL_VALUE_ENTERED =~ ^[0-9]+$ ]] || [[ $FIREWALL_VALUE_ENTERED -gt 3 ]] ; do
        echo "You have entered an invalid choice."
        read -r -p "Enter a number to choose one from 0 to 3: " FIREWALL_VALUE_ENTERED
done

if [[ $FIREWALL_VALUE_ENTERED -eq 0 ]] ; then
    echo "Configuring the iptables. Enter your root password"
    sudo iptables -A INPUT -p tcp -m tcp --dport $JYPTER_NOTEBOOK_PORT -j ACCEPT

elif [[ $FIREWALL_VALUE_ENTERED -eq 1 ]] ; then
    echo "Configuring the Firewalld. Enter your root password""
    sudo firewall-cmd --permanent --zone=public --add-port=$JYPTER_NOTEBOOK_PORT/tcp
    sudo firewall-cmd --reload

elif [[ $FIREWALL_VALUE_ENTERED -eq 2 ]] ; then
    echo "Configuring the UFW. Enter your root password""
    sudo ufw allow $JYPTER_NOTEBOOK_PORT

elif [[ $FIREWALL_VALUE_ENTERED -eq 3 ]] ; then
    echo "Skipping firewall configuration. Try one of these options to configure your firewall:"

    echo "iptables"
    echo "sudo iptables -A INPUT -p tcp -m tcp --dport $JYPTER_NOTEBOOK_PORT -j ACCEPT"

    echo "Firewalld"
    echo "sudo firewall-cmd --permanent --zone=public --add-port=$JYPTER_NOTEBOOK_PORT/tcp"
    echo "sudo firewall-cmd --reload"

    echo "UFW"
    echo "sudo ufw allow $JYPTER_NOTEBOOK_PORT"
fi

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------

echo "Running Jupyter Notebook in the background"
nohup bash -c "jupyter notebook" &

PREFIX="${HOME:-/opt}/anaconda3"
echo "========> Anaconda packages are located in: $PREFIX"
echo "========> Jupyter Notebook's directory: $JUPYTER_NOTEBOOK_DIR"
echo "========> To deactivate, enter: conda deactivate"
echo "========> To relaunch Jupyter Notebook after shutdown/reboot/closed, run: nohup bash -c "jupyter notebook" &"

echo -e "\n"

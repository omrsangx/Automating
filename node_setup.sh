#!/bin/bash

# This script will go through the process of setting up Node.js
# Author: omrsangx

ROOT=$(whoami)
DATE=$(date +%Y_%m_%d_%H_%M)
INSTALLATION_LOG="/tmp/node_setup_$DATE.log"
# OS_VERSION=$(grep -iE "^ID=" /etc/os-release | awk -F"=" '{print $2}')
OS_VERSION=$(grep -iE "^ID=" /etc/os-release | grep -oE "rhel|ubuntu")
NODE_VERSION="v18.16.1"
NODE_APP_DIRECTORY="/home/$USER/node-app"

# Checking access level
if [ $ROOT = "root" ] ; then
    echo "$(whoami) is a root user"
    echo "Run script as a non-root user"
    echo "Terminating the script"
    exit 1    
fi

if [ $OS_VERSION == "rhel" ] || [ $OS_VERSION == "centos" ] ; then
    echo "CentOS/RHEL"
    sudo yum update -y | tee -a $INSTALLATION_LOG
    sudo yum install npm curl -y | tee -a $INSTALLATION_LOG
fi

if [ $OS_VERSION == "ubuntu" ] || [ $OS_VERSION == "debian" ] ; then
    echo "Ubuntu/Debian"
    sudo apt update -y | tee -a $INSTALLATION_LOG
    sudo apt install npm curl -y | tee -a $INSTALLATION_LOG
fi

cd $NODE_APP_DIRECTORY
echo -e "\n"
echo "Installing NVM"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash | tee -a $INSTALLATION_LOG
source ~/.bashrc
echo -e "\n"

command -v nvm

nvm install $NODE_VERSION | tee -a $INSTALLATION_LOG
node -v
npm init -y

echo "NPM, NVM, and Node version"
npm -v
nvm -v
node -v

if [ ! -d "$NODE_APP_DIRECTORY" ] ; then
        mkdir $NODE_APP_DIRECTORY
fi

cat << EOF > $NODE_APP_DIRECTORY/app.js
    console.log("Hello from Node.js")
EOF

echo -e "\n"
node $NODE_APP_DIRECTORY/app.js | tee -a $INSTALLATION_LOG
echo -e "\n"

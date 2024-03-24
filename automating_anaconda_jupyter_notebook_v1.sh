#!/bin/bash

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
JUPYTER_CERTIFICATE="/home/$USER/.jupyter/certs"
JUPYTER_NOTEBOOK_IP_ADDRESS="192.168.5.200"
JYPTER_NOTEBOOK_PORT=8989

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
wget -O anaconda3-2024.sh https://repo.anaconda.com/archive/Anaconda3-2024.02-1-Linux-x86_64.sh
bash anaconda3-2024.sh -b

echo "========> Initilizing Anaconda"
echo "========> Initilizing Anaconda"

$ANACONDA_INSTALLATION_DIR/bin/conda init 

echo "Activating Anaconda"
source ~/.bashrc
conda activate
conda update --all --yes

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------

echo "========> Configuring Jupyter Notebook"
source ~/.bashrc
jupyter notebook --generate-config

echo "========> Configuring Jupyter Notebook password hash"
read -r -p "Enter a password to use with Jupyter Notebook: " JUPYTER_NOTEBOOK_PASSWORD

JUPYTER_HASH=$(echo -n "$JUPYTER_NOTEBOOK_PASSWORD" | argon2 saltItWithSalt -l 32 | grep -i "Encoded" | awk -F":" '{print $2}' | sed -e 's/^[ \t]*//')
echo "========> Password has: $JUPYTER_HASH"

cat << EOF > ~/.jupyter/jupyter_notebook_config.json
{
  "NotebookApp": {
    "password": "$JUPYTER_HASH"
  }
}
EOF

echo "========> Generating a key and self-signed certificate for Jupyter Notebook"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $JUPYTER_CERTIFICATE/jupyter_notebook.key -out $JUPYTER_CERTIFICATE/jupyter_notebook.pem
	
echo "========> Configuring jupyter_notebook_config.py"
read -r -p "Enter the IPv4 Address to host Jupyter Notebook: " JUPYTER_NOTEBOOK_IP_ADDRESS
read -r -p "Enter the port number for Jupyter Notebook to use: " JYPTER_NOTEBOOK_PORT

echo "========> Backing up Jupyter's default configuration file"
mv ~/.jupyter/jupyter_notebook_config.py ~/.jupyter/jupyter_notebook_config.py.backup

cat << EOL > ~/.jupyter/jupyter_notebook_config.py

c.NotebookApp.certfile = u'$JUPYTER_CERTIFICATE/jupyter_notebook.pem'
c.NotebookApp.keyfile = u'$JUPYTER_CERTIFICATE/jupyter_notebook.key'

c.NotebookApp.port = $JYPTER_NOTEBOOK_PORT
c.NotebookApp.open_browser = False
c.NotebookApp.ip = '$JUPYTER_NOTEBOOK_IP_ADDRESS'

EOL

echo "Running Jupyter Notebook in the background"
# nohup bash -c "jupyter notebook" &

PREFIX="${HOME:-/opt}/anaconda3"
echo "========> Anaconda packages are located in: $PREFIX"
echo "========> Jupyter Notebook's directory: $JUPYTER_NOTEBOOK_DIR"
echo "========> To deactivate, enter: conda deactivate"
echo "========> To relaunch Jupyter Notebook after shutdown/reboot/closed, run: nohup bash -c "jupyter notebook" &"

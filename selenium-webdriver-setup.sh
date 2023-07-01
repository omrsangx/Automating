#!/bin/bash

# The following goes through the process setup Selenium Webdriver in Node.js
# Author: omrsangx

ROOT=$(whoami)
NODE_VERSION='v18.16.1'
SELENIUM_DIRECTORY='/home/$USER/selenium-webdirver'
DRIVER_DIRECTORY="$SELENIUM_DIRECTORY/drivers"
SELENIUM_TEST_DRIVER='webDriver.js'
DATE=$(date +%Y_%m_%d_%H_%M)
INSTALLATION_LOG='/tmp/selenium_setup_$DATE.log'
GECKODRIVER_PATH='$SELENIUM_DIRECTORY/geckodriver'
CHROMEDRIVER_PATH='$SELENIUM_DIRECTORY/chromedriver'
OS_VERSION=$(grep -iE "^ID=" /etc/os-release | awk -F"=" '{print $2}')

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
    sudo yum install npm zip unzip wget curl -y | tee -a $INSTALLATION_LOG
    sudo yum install chromium-browser firefox -y | tee -a $INSTALLATION_LOG
fi

if [ $OS_VERSION == "ubuntu" ] || [ $OS_VERSION == "debian" ] ; then
    echo "Ubuntu/Debian"
    sudo apt update -y | tee -a $INSTALLATION_LOG
    sudo apt install npm zip unzip wget curl -y | tee -a $INSTALLATION_LOG
    sudo apt install chromium-browser firefox -y | tee -a $INSTALLATION_LOG
fi

if [ ! -d "$SELENIUM_DIRECTORY" ] ; then
        mkdir $SELENIUM_DIRECTORY
fi

if [ ! -d "$DRIVER_DIRECTORY" ] ; then
        mkdir $DRIVER_DIRECTORY
fi

cd $SELENIUM_DIRECTORY

echo -e "\n"
echo "Installing NVM"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash | tee -a $INSTALLATION_LOG
source ~/.bashrc
echo -e "\n"

nvm install $NODE_VERSION | tee -a $INSTALLATION_LOG
node -v
npm init -y
npm install selenium-webdriver

cat << EOF > $SELENIUM_DIRECTORY/$SELENIUM_TEST_DRIVER

const { Builder, By, Key, until } = require('selenium-webdriver');
const firefox = require('selenium-webdriver/firefox');

async function runScript() {
  let options = new firefox.Options().headless();
  let driver = await new Builder().forBrowser('firefox').setFirefoxOptions(options).build();

  try {
    // Navigating to example.com
    await driver.get('https://example.com');

    // Printing html h1's text
    let getWebElement = await driver.findElement(By.css('h1'));
    let getWebText = await getWebElement.getText();
    console.log(getWebText)

  } finally {
    // Quitting the driver
    await driver.quit();
  }
}

runScript().catch(err => console.error(err));

EOF

echo -e "\n"
echo "Running the $SELENIUM_TEST_DRIVER application"
node $SELENIUM_TEST_DRIVER
echo -e "\n"

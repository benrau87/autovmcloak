#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD

##Logging setup
logfile=/var/log/vmcloak_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

##Functions
function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y --allow-unauthenticated ${@} &>> $logfile
error_check 'Package installation completed'

}

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

echo -e "${YELLOW}What is your cuckoo user account name?${NC}" &>> $logfile
read user


apt-get install mkisofs genisoimage -y &>> $logfile
sudo mkdir -p /mnt/windows_ISOs &>> $logfile
##VMCloak
echo
read -n 1 -s -p "Please place your Windows ISO(s) in the folder under /mnt/windows_ISOs and press any key to continue"
echo

pip install vmcloak --upgrade &>> $logfile
error_check 'PIP install of vmcloak'

mount -o loop,ro  --source /mnt/windows_ISOs/*.iso --target /mnt/windows_ISOs/ &>> $logfile
error_check 'Mounted all ISOs'

echo -e "${YELLOW}What is the Windows disto?"
read distro
echo -e "${YELLOW}What is the IP  address?"
read ipaddress
echo -e "${YELLOW}What is the name for this machine?"
read name
echo -e "${YELLOW}What is the key?"
read key


echo -e "${YELLOW}###################################${NC}"
echo -e "${YELLOW}This process will take some time, you should get a sandwich, or watch the install if you'd like...${NC}"
echo
sleep 5
vmcloak init --vm-visible --hwvirt --ramsize 2048  --$distro --serial-key $key --iso-mount /mnt/windows_ISOs/ $name &>> $logfile
error_check 'Created VMs'
vmcloak install $name adobe9 wic pillow dotnet40 java7 &>> $logfile
error_check 'Installed adobe9 wic pillow dotnet40 java7 on VMs'


echo
read -p "Would you like to install Office 2007? This WILL require an ISO and key. Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo -e "${YELLOW}What is the path to the iso?${NC}"
  read path
  echo
  echo -e "${YELLOW}What is the license key?${NC}"
  read key
  vmcloak install seven0 office2007 \
    office2007.isopath=$path \
    office2007.serialkey=$key
fi
echo
echo -e "${YELLOW}Starting VM and creating a running snapshot...Please wait.${NC}"  
vmcloak snapshot $name vmcloak $ipaddress &>> $logfile
error_check 'Created snapshots'


chown -R $user:$user ~/.vmcloak

echo
echo -e "${YELLOW}The VM is located under your current OR sudo user's home folder under .vmcloak, you will need to register this with Virtualbox on your cuckoo account.${NC}"  


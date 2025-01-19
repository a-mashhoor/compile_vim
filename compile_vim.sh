#!/usr/bin/bash

# Exit on Any error
set -e

# checking for root privileges
if [[ $EUID -ne 0 ]]; then
	echo "You must be root to run the script" 1>&2
	exit 100
fi

# finding the right package manager

# finding OS
OS=$(uname -s | tr A-Z a-z)

# finding distro and based on distro selecting a package manager
case $OS in
	linux)
		echo -n OS is LINUX!
		source /etc/os-release
		case $ID_LIKE in
			debian)
				echo OS is Debian based selecting apt as package manager
				purge_cmd="apt purge"
				update_CMD="apt update"
				install_CMD="apt install"
				;;
			arch*)
				echo OS is Arch based selecting pacman as package manager
				purge_cmd="pacman -Rs"
				update_CMD="pacman -Syyu"
				install_CMD="pacman -S"
				;;
			rhel*)
				echo OS is Red Hat based selecting yum as package manager
				purge_cmd="yum remove"
				update_CMD="yum update"
				install_CMD="yum install"
				;;
			*)
				echo  distro not supported
				exit 1
		esac
		;;
	darwin)
		echo OS is OS X selecting brew as package manager
		purge_cmd="brew uninstall"
		update_CMD="brew update"
		install_CMD="brew install"
		;;
	*) echo operating system not supported
		exit 1
		;;
esac

# update the repositories
echo Updating the repositories
$update_CMD

# Install git if not installed
echo "Checking for Git installation..."
if ! command -v git &>/dev/null; then
	echo "Git not found, installing it"
	$install_CMD git -y
fi

# Install Python3 if not installed
echo "Checking for Python3 installation..."
if ! command -v python3 &>/dev/null; then
	echo "Python3 not found, installing it"
	$install_CMD python3-full -y
fi

echo removing existing installation of vim if any
if command -v vim &>/dev/null; then
	echo vim installation found removing it
	$purge_cmd vim vim-gtk3 vim-runtime gvim vim-tiny vim-common vim-gui-common -y
fi

echo Cloning vim in a while loop until the clone is finished
while ! -d vim; do
	git clone https://github.com/vim/vim.git vim
done

echo change directory to vim
cd vim

echo Installing dependencies
dependencies=(
	"libncurses5-dev"
	"libgtk2.0-dev"
	"libatk1.0-dev"
	"libcairo2-dev"
	"libx11-dev"
	"libxpm-dev"
	"libxt-dev"
	"python3-dev"
	"ruby-dev"
	"mercurial"
	"sed"
	"awk"
	"curl"
	"make"
	"nproc"
)
# Installing dependencies
$install_CMD "${dependencies[@]}" -y

python_v=$(python3 --version | awk '{print $2}' | sed -e 's/..$//g')
python_config_dir="/usr/lib/python$python_v/config-$python_v-x86_64-linux-gnu/"

# my custom config for compiling vim
echo configuring VIM
./configure --with-features=huge --enable-multibyte --with-x --enable-rubyinterp \
	--enable-python3interp --with-python-config-dir=$python_config_dir \
	--with-python3-command=python3 --enable-terminal --enable-cscope \
	--prefix=/usr/local --enable-gtk2-check --enable-gtk3-check \
	--enable-gtktest --enable-gui=auto

# building and installing vim
echo Building and installing VIM
sudo make -j$(nproc) VMRUNTIMEDIR=/usr/share/vim/vim9
sudo make install

# Creating vim related directories for user
mkdir -p ~/.vim/{backup,colors,plugged}

# vim plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
	https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "enjoy vim with full features! And plug manager"



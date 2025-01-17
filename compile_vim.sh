#!/usr/bin/bash

# checking for root privileges
if [[ $EUID -ne 0 ]]; then
	echo "You must be root to run the script" 1>&2
	exit 100
fi

# finding the right package manager

OS=$(uname -s | tr A-Z a-z)

case $OS in
	linux)
		echo -n OS is LINUX!
		source /etc/os-release
		case $ID_LIKE in
			debian)
				echo OS is Debian based
				purge_cmd="apt purge"
				update_CMD="apt update"
				install_CMD="apt install"
				;;
			arch*)
				echo OS is Arch based
				purge_cmd="pacman -Rs"
				update_CMD="pacman -Syyu"
				install_CMD="pacman -S"
				;;
			rhel*)
				echo OS is Red Hat based
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
		echo OS is OS X using brew as package manager
		purge_cmd="brew uninstall"
		update_CMD="brew update"
		install_CMD="brew install"
		;;
	*) echo operating system not supported
		exit 1
		;;
esac

# update the repos
$update_CMD


if ! git; then
	$install_CMD git -y
fi

if ! python3; then
	$install_CMD python3-full -y
fi

if vim; then
	$purge_cmd vim vim-gtk3 vim-runtime gvim vim-tiny vim-common vim-gui-common -y
fi

while ! -d vim; do
	git clone https://github.com/vim/vim.git vim
done

cd vim

# Installing dependencies
$install_CMD libncurses5-dev libgtk2.0-dev libatk1.0-dev libcairo2-dev libx11-dev \
	libxpm-dev libxt-dev python3-dev ruby-dev mercurial sed awk curl -y

python3version=$(python3 --version | awk '{print $2}' | sed -e 's/..$//g')

# my custom config for compiling
./configure --with-features=huge --enable-multibyte --with-x --enable-rubyinterp \
	--enable-python3interp --with-python-config-dir=/usr/lib/python$python3version/config-$python3version-x86_64-linux-gnu/ \
	--with-python3-command=python3 --enable-terminal --enable-cscope \
	--prefix=/usr/local --enable-gtk2-check --enable-farsi --enable-gtk3-check \
	--enable-gtktest --enable-gui=auto

# making and building binary !!!!
make VMRUNTIMEDIR=/usr/share/vim/vim9
make install

# Creating vim related directories for user
mkdir -p ~/.vim/{autoload,backup,colors,plugged}

# vim plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
	https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "enjoy vim with full features! And plug manager"



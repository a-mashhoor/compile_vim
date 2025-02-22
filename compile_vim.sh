#!/usr/bin/bash

# Exit on Any error
set -e

# checking for root privileges
if [[ $EUID -ne 0 ]]; then
	echo "You must be root to run the script" 1>&2
	exit 100
fi

# Parse command-line arguments
quiet=0
while getopts "q" opt; do
	case $opt in
		q) quiet=1 ;;
		*) echo "Usage: $0 [-q]"; exit 1 ;;
	esac
done


# Function to print messages only if not in quiet mode
log() {
	if [[ $quiet -eq 0 ]]; then
		echo "$@"
	fi
}

# finding the right package manager

# finding OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]' )

# finding distro and based on distro selecting a package manager
case $OS in
	linux)
		log "OS is LINUX!"
		source /etc/os-release
		case $ID_LIKE in
			*debian*)
				log "OS is Debian-based selecting apt as package manager"
				purge_cmd="apt purge -y"
				update_CMD="apt update -y"
				install_CMD="apt install -y"
				dependencies=(
					"libncurses5-dev" "libgtk2.0-dev" "libatk1.0-dev" "libcairo2-dev"
					"libx11-dev" "libxpm-dev" "libxt-dev" "python3-dev" "ruby-dev"
					"mercurial" "sed" "gawk" "curl" "make"
				)
				;;
			arch*)
				log "OS is Arch-based selecting pacman as package manager"
				purge_cmd="pacman -Rs --noconfirm"
				update_CMD="pacman -Syyu --noconfirm"
				install_CMD="pacman -S --noconfirm"
				dependencies=(
					"ncurses" "gtk2" "atk" "cairo" "libx11" "libxpm" "libxt"
					"python" "ruby" "mercurial" "sed" "gawk" "curl" "make"
				)
				;;
			rhel*)
				log "OS is Red-Hat based selecting yum as package manager"
				purge_cmd="yum remove -y"
				update_CMD="yum update -y"
				install_CMD="yum install -y"
				dependencies=(
					"ncurses-devel" "gtk2-devel" "atk-devel" "cairo-devel"
					"libX11-devel" "libXpm-devel" "libXt-devel" "python3-devel"
					"ruby-devel" "mercurial" "sed" "gawk" "curl" "make"
				)
				;;
			*)
				log  "distro not supported"
				exit 1
		esac
		;;
	darwin)
		log "OS is macOS selecting brew as package manager"
		purge_cmd="brew uninstall"
		update_CMD="brew update"
		install_CMD="brew install"
		dependencies=(
			"ncurses" "gtk+" "atk" "cairo" "python@3" "ruby" "mercurial" "sed" "gawk" "curl" "make"
		)
		;;
	*)
		echo "operating system not supported"
		exit 1
		;;
esac

# update the repositories
log "Updating the repositories"
$update_CMD

# Install git if not installed
log "Checking for Git installation..."
if ! command -v git &>/dev/null; then
	log "Git not found, installing it"
	$install_CMD git
fi

# Install Python3 if not installed
log "Checking for Python3 installation..."
if ! command -v python3 &>/dev/null; then
	log "Python3 not found, installing it"
	$install_CMD python3-full
fi

log "removing existing installation of vim if any"
if command -v vim &>/dev/null; then
	log "vim installation found"

	if [[ $quiet -eq 0 ]]; then
		read -p "You already have a VIM installed do you want to remove it and compile vim again? (y/n): " reinstall
	else
		reinstall="y"  # Default to deleting in quiet mode
	fi

	if [[ $reinstall = "y" || $reinstall = "Y" ]]; then
		log "removing vim from system"
		$purge_cmd vim vim-gtk3 vim-runtime gvim vim-tiny vim-common vim-gui-common
	else
		log "Closing the script due to user order to not compile vim again"
		exit 0
	fi
fi

log "Cloning vim in a while loop until the clone is finished"
# Function to clone the repository
clone_repo() {

	# Variables
	local MAX_ATTEMPTS=20
	local ATTEMPT=0
	# Retry logic using a do-while loop (bash do not support do-while so we are making one!)
	while true; do
		log "Attempting to clone repository (Attempt $ATTEMPT of $MAX_ATTEMPTS)..."
		git clone "$@"

	    # Check the exit status of the git clone command
	    if [ $? -eq 0 ]; then
		    log "Repository cloned successfully!"
		    break  # Exit with success
	    else
		    log "Failed to clone repository. Retrying..."
		    ATTEMPT=$((ATTEMPT + 1))
		    if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
			    echo "Failed to clone repository after $MAX_ATTEMPTS attempts."
			    exit 1  # Exit with failure
		    fi
		    sleep 0.5 # Wait for 5 seconds before retrying
	    fi
    done
}

if [[ ! -d vim ]];then
	clone_repo https://github.com/vim/vim.git vim
else
	log "Source Code aleardy exists"
fi

log "change directory to vim or exit"
cd vim || exit

log "Installing dependencies"

sleep 1

# Installing dependencies
$install_CMD "${dependencies[@]}"

python_config_dir=$(python3-config --configdir 2>/dev/null ||
	python3 -m sysconfig --configdir 2>/dev/null ||
	echo "")

if [[ -z "$python_config_dir" ]]; then
	log "Warning: Python config directory not found. Vim's Python3 integration might not work."
	log "Consider installing python3-dev or equivalent package for your distribution."
	python3V=$(python3 --version | awk '{print $2}' | sed -e 's/..$//g')
	python_config_dir="/usr/lib/python$python3V/config-$python3V-x86_64-linux-gnu/"
	log "Using fallback path: $python_config_dir"
fi

# my custom config for compiling vim
log "configuring VIM"
sleep 1
./configure --with-features=huge \
	--enable-multibyte \
	--with-x \
	--enable-rubyinterp \
	--enable-python3interp \
	--with-python-config-dir=$python_config_dir \
	--with-python3-command=python3 \
	--enable-terminal \
	--enable-cscope \
	--prefix=/usr/local \
	--enable-gtk2-check \
	--enable-gtk3-check \
	--enable-gtktest \
	--enable-gui=auto

# building and installing vim
echo Building and installing VIM
sleep 1
max_retries=3
retry_count=0

echo "Building and installing Vim..."
while [[ $retry_count -lt $max_retries ]]; do
	if make -j$(nproc) VMRUNTIMEDIR=/usr/share/vim/vim9 ; then
		log "Vim built successfully!"
		break
	else
		retry_count=$((retry_count + 1))
		log "Build failed. Retry attempt $retry_count of $max_retries..."
		make clean  # Clean up previous build artifacts
	fi
done

if [[ $retry_count -eq $max_retries ]]; then
	echo "Error: Vim build failed after $max_retries attempts. Exiting."
	exit 1
fi
sleep 1
make install

# Detect the actual user's home directory
if [[ -n "$SUDO_USER" ]]; then
	USER_HOME=$(eval echo ~"$SUDO_USER")
else
	USER_HOME=$HOME
fi
# Create Vim directories in the user's home folder
log "Setting up Vim directories for $USER_HOME..."

# Creating vim related directories for user
mkdir -p $USER_HOME/.vim/{backup,colors,plugged}

log "installing the Plug Pluggin manager"
# vim plug
curl -fLos "$USER_HOME/.vim/autoload/plug.vim" --create-dirs \
	https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Ask the user if they want to keep the Vim source code
if [[ $quiet -eq 0 ]]; then
	read -p "Do you want to keep the Vim source code for debugging or customization? (y/n): " keep_source
else
	keep_source="n"  # Default to deleting in quiet mode
fi

# Clean up the Vim source directory
if [[ $keep_source != "y" ]] || [[ $keep_source != "Y" ]]; then
	log "Cleaning up Vim source directory..."
	cd ..
	rm -rf vim
else
	log "Vim source code retained in: $(pwd)/vim"
fi

log "enjoy vim with full features! And plug manager"

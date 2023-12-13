#!/usr/bin/env bash
set -e -u -o pipefail

REPO_DIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)
TERMUX_BASE_DIR="/data/data/com.termux/files"
TERMUX_HOME="$TERMUX_BASE_DIR/home"
TERMUX_PREFIX="$TERMUX_BASE_DIR/usr"

: ${TERMUX_ARCH:=x86_64}

# Test if PACKAGE_TO_BUILD is set or not
echo "Package(s) to build: $PACKAGE_TO_BUILD"

ABI=
case $TERMUX_ARCH in
	aarch64)
		ABI="arm64-v8a"
	;;
	arm) 
		ABI="armeabi-v7a"
	;;
	i686) 
		ABI="x86"
	;;
	x86_64) 
		ABI="x86_64"
	;;
	*)
		echo "Invalid arch."
		exit 1
	;;
esac

# Work around possible frozen
waydroid prop set persist.waydroid.suspend false
waydroid session stop
waydroid session start &
waydroid show-full-ui
waydroid prop set persist.waydroid.suspend false
sleep 30

# Get IP address of Waydroid container
waydroid_ip="$(waydroid status | grep -oP 'IP address:\s+\K[\d.]+')"

# Get and install Termux APK
URL=https://github.com/termux/termux-app/releases/download/v0.118.0/termux-app_v0.118.0+github-debug_$ABI.apk
wget $URL
waydroid app install $REPO_DIR/$(basename $URL)
rm -f $REPO_DIR/$(basename $URL)

# Sleep 10s to ensure that Termux has been successfully installed
sleep 10

# Start Termux
sudo waydroid shell -- am start -n com.termux/com.termux.app.TermuxActivity

# Sleep 10s to ensure that Termux has been successfully started
sleep 10

# OK. Now we have Termux bootstrap installed. Kill Termux now
sudo waydroid shell -- am force-stop com.termux

# Install openssh in Termux
sudo waydroid shell -- run-as com.termux sh -c "echo 'apt update && touch 1 && apt dist-upgrade -o Dpkg::Options::=--force-confnew -y && touch 2 && apt update && touch 3 && apt install openssh -yqq && touch 4' > /data/data/com.termux/files/home/.bashrc"
sudo waydroid shell -- am start -n com.termux/com.termux.app.TermuxActivity

check_file_exists() {
	local path="$1"
	local counter=0
	while ! [ $(sudo waydroid shell -- run-as com.termux sh -c '[ -e "$1" ]; echo $?' - "$path") = 0 ]; do
		sleep 10s
		counter=$[counter+1]
		echo "Wait $counter time(s) for $path exists"
	done
}

check_file_exists /data/data/com.termux/files/home/1
check_file_exists /data/data/com.termux/files/home/2
check_file_exists /data/data/com.termux/files/home/3
check_file_exists /data/data/com.termux/files/home/4

sudo waydroid shell -- am force-stop com.termux

# Generate ssh-key for Termux
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
public_key="$(cat ~/.ssh/id_rsa.pub)"

# Add ssh-key to Termux's authorized_keys
sudo waydroid shell -- run-as com.termux sh -c "echo '$public_key' >> /data/data/com.termux/files/home/.ssh/authorized_keys"

# Start sshd in Termux
sudo waydroid shell -- run-as com.termux sh -c "echo 'sshd' > /data/data/com.termux/files/home/.bashrc"
sudo waydroid shell -- am start -n com.termux/com.termux.app.TermuxActivity
sleep 10

# Execute `ls -al` with ssh for testing
ssh -o StrictHostKeyChecking=no "$waydroid_ip" -p 8022 -- ls -al

# Connect to Waydroid connect with adb
scp -r -o StrictHostKeyChecking=no $REPO_DIR/ "$waydroid_ip":$TERMUX_HOME/repo -p 8022

# Build packages
ssh -o StrictHostKeyChecking=no "$waydroid_ip" -p 8022 -- "cd $TERMUX_HOME/repo && ./scripts/setup-termux.sh"
ssh -o StrictHostKeyChecking=no "$waydroid_ip" -p 8022 -- "cd $TERMUX_HOME/repo && ./build-package.sh -I $PACKAGE_TO_BUILD"

# Pull result
rm -rf ./output
scp -r -o StrictHostKeyChecking=no $TERMUX_HOME/repo/output "$waydroid_ip":./ -p 8022

#!/bin/sh

main() {
	echo "Installing tools for Debian"

	echo "Updating and upgrading system"
	sudo apt update -y
	sudo apt upgrade -y

	echo "Installing Snap"
	sudo apt install snapd -y

	echo "Installing curl"
	sudo apt install curl -y

	echo "Installing Github CLI"
	sudo apt install gh -y

	echo "Installing Brave Browser"
	sudo apt install brave-browser -y

	echo "Installing Docker"
	sudo apt install docker.io -y

	echo "Installing VSCode"
	install_vscode

	echo "Installing Moonlight"
	sudo snap install moonlight

	echo "Installing btop"
	sudo apt install btop
}

install_vscode() {

	sudo apt install wget gpg -y
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
	rm -f packages.microsoft.gpg

	sudo apt install apt-transport-https -y
	sudo apt update
	sudo apt install code -y # or code-insiders
}


main

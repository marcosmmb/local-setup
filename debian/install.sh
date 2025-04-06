#!/bin/sh

main() {
	echo "Installing tools for Debian"

	echo "Updating and upgrading system"
	sudo apt update
	sudo apt upgrade

	echo "Installing Snap"
	sudo apt install snapd

	echo "Installing curl"
	sudo apt install curl

	echo "Installing Github CLI"
	sudo apt install gh

	echo "Installing Brave Browser"
	sudo apt install brave-browser

	echo "Installing Docker"
	sudo apt install docker.io

	echo "Installing VSCode"
	install_vscode

	echo "Installing Moonlight"
	sudo snap install moonlight

	echo "Installing btop"
	sudo snap install btop 
}

install_vscode() {

	sudo apt install wget gpg
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
	rm -f packages.microsoft.gpg
	
	sudo apt install apt-transport-https
	sudo apt update
	sudo apt install code # or code-insiders
}


main

#!/bin/sh

main() {
	echo "Installing tools for Debian"

	echo "Updating and upgrading system"
	sudo apt update
	sudo apt upgrade
	
	echo "Installing curl"
	sudo apt install curl
	
	echo "Installing Github CLI"
	sudo apt install gh
	
	echo "Installing Brave Browser"
	sudo apt install brave-browser
}
main

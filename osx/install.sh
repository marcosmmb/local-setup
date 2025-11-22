#!/usr/bin/env bash

install() {
    local package_name="$1"
    local cask="$2"

    if [[ -z "$package_name" ]]; then
        echo "Error: package_name is required."
        return 1
    fi

    if [[ "$cask" == "cask" ]]; then
        echo "Installing cask: $package_name..."
        brew install --cask "$package_name"
    else
        echo "Installing package: $package_name..."
        brew install "$package_name"
    fi
}

echo "Installing tools"
# install homebrew
echo "Installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


install docker cask
install stats cask
install displaylink cask
koekeishiya/formulae/yabai
yabai --start-service
install koekeishiya/formulae/skhd
skhd --start-service
install btop
install gh
install tabby cask
install visual-studio-code cask
install brave-browser cask
install bitwarden cask
install moonlight cask
install raycast
install ffmpeg
install nmap
install ipython
install pipx
install awscli
install obsidian cask
install spotify cask
install gnupg

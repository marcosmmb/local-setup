echo "Installing tools"

# install homebrew
echo "Installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install docker\
echo "Installing Docker"
brew install --cask docker
docker --version

# install stats
echo "Installing Stats"
brew install --cask stats

# download DisplayLink
# https://www.synaptics.com/products/displaylink-graphics/downloads/macos

# install yabai
# https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)
echo "Installing yabai"
brew install koekeishiya/formulae/yabai
yabai --start-service

# install skhd
# https://github.com/koekeishiya/skhd
echo "Installing skhd"
brew install koekeishiya/formulae/skhd
skhd --start-service

# install minicom (serial comunication tool)
echo "Installing Minicom"
brew install minicom

# install 1password cli
echo "Installing 1Password CLI"
brew install --cask 1password/tap/1password-cli

# install btop
echo "Installing btop"
brew reinstall btop

# install github cli
echo "Installing Github CLI"
brew install gh

# install tabby
echo "Installing Tabby"
brew install --cask tabby

# install vs code
echo "Installing VS Code"
brew install --cask visual-studio-code

# install brave browser
echo "Installing Brave"
brew install --cask brave-browser

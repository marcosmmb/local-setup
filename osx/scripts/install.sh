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
brew services start yabai

# install skhd
# https://github.com/koekeishiya/skhd
echo "Installing skhd"
brew install koekeishiya/formulae/skhd
brew services start skhd


# install minicom (serial comunication tool)
echo "Installing Minicom"
brew install minicom

# apply files from repo into local directories
echo "Applying files from repository to local"

echo "Copying .zprofile"
cp ~/.zprofile ~/.zprofile.old
cp ./osx/home/.zprofile ~/.zprofile

echo "Copying .zshrc"
cp ~/.zshrc ~/.zshrc.old
cp ./osx/home/.zshrc ~/.zshrc

echo "Copying .ssh"
cp ~/.ssh/config ~/.ssh/config.old
cp ./osx/home/ssh ~/.ssh/config

echo "Copying skhd"
cp -r ~/.skhdrc ~/.skhdrc_old
cp -r ./osx/home/config/skhd/skhdrc ~/.skhdrc

echo "Copying yabai"
cp -r ~/.yabairc ~/.yabairc_old
cp -r ./osx/home/config/yabai/yabairc ~/.yabairc

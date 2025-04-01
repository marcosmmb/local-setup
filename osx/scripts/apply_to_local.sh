# apply files from repo into local directories
echo "Applying files from repository to local"

echo "Copying .zprofile"
cp ./osx/home/.zprofile ~/.zprofile

echo "Copying .zshrc"
cp ./osx/home/.zshrc ~/.zshrc

echo "Copying .ssh"
cp ./osx/home/ssh ~/.ssh/config

echo "Copying skhd"
cp -r ./osx/home/config/skhd/skhdrc ~/.skhdrc

echo "Copying yabai"
cp -r ./osx/home/config/yabai/yabairc ~/.yabairc

# apply files from repo into local directories
echo "Copying .zprofile"
cp ./osx/home/.zprofile ~/.zprofile

echo "Copying .zshrc"
cp ./osx/home/.zshrc ~/.zshrc

echo "Copying skhd"
cp -r ./osx/home/config/skhd/skhdrc ~/.skhdrc

echo "Copying yabai"
cp -r ./osx/home/config/yabai/yabairc ~/.yabairc

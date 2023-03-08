# replicate local files into repo
echo "Copying .zprofile"
cp ~/.zprofile ./osx/home/

echo "Copying .zshrc"
cp ~/.zshrc ./osx/home/

echo "Copying skhd"
cp -r ~/.config/skhd ./osx/home/.config/

echo "Copying yabai"
cp -r ~/.config/yabai ./osx/home/.config/

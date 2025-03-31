# replicate local files into repo
echo "Copying .zprofile"
cp ~/.zprofile ./osx/home/

echo "Copying .zshrc"
cp ~/.zshrc ./osx/home/

echo "Copying skhd"
cp -r ~/.skhdrc ./osx/home/config/skhd/skhdrc

echo "Copying yabai"
cp -r ~/.yabairc ./osx/home/config/yabai/yabairc

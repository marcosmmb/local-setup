# replicate local files into repo
echo "Replicating file from local to repository"

echo "Copying .zprofile"
cp ~/.zprofile ./osx/home/

echo "Copying .zshrc"
cp ~/.zshrc ./osx/home/

echo "Copying .ssh"
cp ~/.ssh/config ./osx/home/ssh

echo "Copying skhd"
cp -r ~/.skhdrc ./osx/home/config/skhd/skhdrc

echo "Copying yabai"
cp -r ~/.yabairc ./osx/home/config/yabai/yabairc

#!/bin/sh
set -eu

echo "Authenticating for installation"
sudo -v

# Keep the initial authentication valid during long downloads and installations.
installer_pid=$$
(
	while kill -0 "$installer_pid" 2>/dev/null; do
		sudo -n -v || exit 1
		sleep 60
	done
) >/dev/null 2>&1 &
sudo_keepalive_pid=$!

cleanup() {
	kill "$sudo_keepalive_pid" 2>/dev/null || true
	wait "$sudo_keepalive_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Skip Homebrew confirmations, including any configured default ask mode.
unset INTERACTIVE
export NONINTERACTIVE=1
export HOMEBREW_NO_ASK=1
# Homebrew uses sudo -A when this is set. Fail instead of prompting again if
# cached credentials become unavailable; never store the password in the script.
export SUDO_ASKPASS=/usr/bin/false

echo "Installing tools"

# Locate an existing installation even if brew is not yet in this shell's PATH.
if ! command -v brew >/dev/null 2>&1; then
	if [ -x /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [ -x /usr/local/bin/brew ]; then
		eval "$(/usr/local/bin/brew shellenv)"
	else
		echo "Installing Homebrew"
		homebrew_installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
		/bin/bash -c "$homebrew_installer" </dev/null
		if [ -x /opt/homebrew/bin/brew ]; then
			eval "$(/opt/homebrew/bin/brew shellenv)"
		else
			eval "$(/usr/local/bin/brew shellenv)"
		fi
	fi
fi

install_programs() {
	package_type=$1
	shift
	printf 'Installing %s\n' "$@"
	brew install "$package_type" "$@" </dev/null
}

install_programs --formula \
	git \
	koekeishiya/formulae/yabai \
	koekeishiya/formulae/skhd \
	btop \
	gh \
	ffmpeg \
	nmap \
	ipython \
	pipx \
	uv \
	awscli \
	gnupg \
	mole

install_programs --cask \
	docker \
	stats \
	displaylink \
	tabby \
	visual-studio-code \
	brave-browser \
	bitwarden \
	moonlight \
	raycast \
	obsidian \
	spotify \
	vorssaint

docker --version </dev/null
yabai --start-service </dev/null
skhd --start-service </dev/null

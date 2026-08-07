#!/usr/bin/env bash
#
# Install packages and third-party apt repositories on a fresh Ubuntu machine.
#
# Idempotent: safe to re-run. Reads the curated package list from
# manifests/apt-install.txt; manifests/apt-manual.txt is the full captured
# record of the source machine and is kept for reference only.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="$REPO_DIR/linux/manifests"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
# Several vendors only publish for LTS codenames; pin those to the LTS base.
LTS_CODENAME="noble"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# key_url dest_keyring -- download and dearmor an ASCII-armoured signing key.
add_key() {
	local url="$1" dest="$2"
	[ -f "$dest" ] && return 0
	sudo install -m 0755 -d "$(dirname "$dest")"
	curl -fsSL "$url" | sudo gpg --dearmor -o "$dest"
	sudo chmod a+r "$dest"
}

# name content -- write /etc/apt/sources.list.d/<name> if not already present.
add_source() {
	local name="$1" content="$2"
	local path="/etc/apt/sources.list.d/$name"
	[ -f "$path" ] && return 0
	echo "$content" | sudo tee "$path" > /dev/null
	echo "    added $name"
}

setup_prereqs() {
	log "Installing prerequisites"
	sudo apt-get update -qq
	sudo apt-get install -y -qq \
		apt-transport-https ca-certificates curl gnupg lsb-release \
		software-properties-common wget
}

setup_repositories() {
	log "Configuring third-party apt repositories"

	# Docker CE
	add_key "https://download.docker.com/linux/ubuntu/gpg" /etc/apt/keyrings/docker.gpg
	add_source docker.list \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable"

	# VS Code
	add_key "https://packages.microsoft.com/keys/microsoft.asc" /usr/share/keyrings/microsoft.gpg
	add_source vscode.list \
		"deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"

	# Brave
	add_key "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
		/usr/share/keyrings/brave-browser-archive-keyring.gpg
	add_source brave-browser-release.list \
		"deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"

	# Google Cloud CLI
	add_key "https://packages.cloud.google.com/apt/doc/apt-key.gpg" /usr/share/keyrings/cloud.google.gpg
	add_source google-cloud-sdk.list \
		"deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main"

	# HashiCorp (terraform)
	add_key "https://apt.releases.hashicorp.com/gpg" /usr/share/keyrings/hashicorp-archive-keyring.gpg
	add_source hashicorp.list \
		"deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $CODENAME main"

	# NodeSource (Node 24.x)
	add_key "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" /etc/apt/keyrings/nodesource.gpg
	add_source nodesource.list \
		"deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main"

	# MongoDB database tools
	add_key "https://www.mongodb.org/static/pgp/server-8.0.asc" /usr/share/keyrings/mongodb-server-8.0.gpg
	add_source mongodb-org-8.0.list \
		"deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu $LTS_CODENAME/mongodb-org/8.0 multiverse"

	# Slack
	add_source slack.list \
		"deb https://packagecloud.io/slacktechnologies/slack/debian/ jessie main"

	# Spotify
	add_key "https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg" \
		/usr/share/keyrings/spotify.gpg
	add_source spotify.list \
		"deb [signed-by=/usr/share/keyrings/spotify.gpg] https://repository.spotify.com stable non-free"

	# Obsidian ships as a .deb rather than a repo; see install_obsidian below.

	sudo apt-get update -qq
}

install_apt_packages() {
	local f="$MANIFEST_DIR/apt-install.txt"
	[ -f "$f" ] || { warn "no apt-install.txt; skipping"; return 0; }
	log "Installing apt packages"
	# shellcheck disable=SC2046
	sudo apt-get install -y $(grep -vE '^\s*(#|$)' "$f" | tr '\n' ' ')
}

install_snaps() {
	command -v snap >/dev/null || { warn "snapd not available; skipping snaps"; return 0; }
	local f="$MANIFEST_DIR/snap.txt"
	[ -f "$f" ] || return 0
	log "Installing snaps"
	while read -r name flags; do
		[ -n "$name" ] || continue
		case "$name" in
			# Bases and platform snaps are pulled in automatically as dependencies.
			core*|bare|snapd|gtk-common-themes|gnome-*|mesa-*|snapd-desktop-integration| \
			desktop-security-center|firmware-updater|prompting-client|snap-store) continue ;;
			# Already installed from apt; the snap would shadow it.
			kubectl|google-cloud-cli) continue ;;
		esac
		snap list "$name" >/dev/null 2>&1 && continue
		# shellcheck disable=SC2086
		sudo snap install "$name" $flags && echo "    $name"
	done < "$f"
}

install_obsidian() {
	dpkg -s obsidian >/dev/null 2>&1 && return 0
	log "Installing Obsidian"
	local url
	url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
		| grep -oE 'https://[^"]*amd64\.deb' | head -1)"
	[ -n "$url" ] || { warn "could not resolve Obsidian release URL"; return 0; }
	curl -fsSL "$url" -o /tmp/obsidian.deb
	sudo apt-get install -y /tmp/obsidian.deb
	rm -f /tmp/obsidian.deb
}

install_oh_my_zsh() {
	[ -d "$HOME/.oh-my-zsh" ] && return 0
	log "Installing oh-my-zsh"
	# --unattended keeps it from launching a shell or rewriting .zshrc, which
	# apply_to_local.sh installs afterwards.
	RUNZSH=no CHSH=no sh -c \
		"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

set_default_shell() {
	[ "$SHELL" = "$(command -v zsh)" ] && return 0
	log "Setting zsh as the default shell"
	chsh -s "$(command -v zsh)"
}

install_go_tools() {
	command -v go >/dev/null || { warn "go not installed; skipping go tools"; return 0; }
	log "Installing Go tools"
	local tools=(
		github.com/go-delve/delve/cmd/dlv@latest
		golang.org/x/tools/gopls@latest
		github.com/josharian/impl@latest
		github.com/haya14busa/goplay/cmd/goplay@latest
	)
	for t in "${tools[@]}"; do
		go install "$t" && echo "    ${t%@*}"
	done
}

install_appimages() {
	local f="$MANIFEST_DIR/appimages.txt"
	[ -f "$f" ] || return 0
	log "AppImages to download manually into ~/Applications"
	sed 's/^/    /' "$f"
	warn "AppImage binaries are not stored in this repository"
}

add_user_to_docker_group() {
	getent group docker >/dev/null || return 0
	id -nG "$USER" | grep -qw docker && return 0
	log "Adding $USER to the docker group"
	sudo usermod -aG docker "$USER"
	warn "log out and back in for docker group membership to take effect"
}

print_skipped() {
	cat <<-'EOF'

	Deliberately not installed by this script:

	  Hardware-specific (Dell Pro Max 14 / Somerville Remoraid)
	    displaylink-driver, v4l2loopback-dkms, v4l2-relayd, v4l-utils,
	    libcamera*, linux-modules-ipu6-oem-*, fprintd, libpam-fprintd,
	    synaptics-repository-keyring, oem-somerville-remoraid-meta
	    -> Ubuntu's OEM enablement installs these automatically on matching
	       hardware. Installing them on a different machine can break the
	       display or camera stack.

	  IT-managed agents
	    amagent, sentinelagent, fleet-osquery
	    -> Enrolled and deployed by Tigera IT. Do not install by hand.
	EOF
}

main() {
	log "Setting up Ubuntu $CODENAME"
	setup_prereqs
	setup_repositories
	install_apt_packages
	install_snaps
	install_obsidian
	install_oh_my_zsh
	set_default_shell
	install_go_tools
	install_appimages
	add_user_to_docker_group
	print_skipped
	echo
	log "Package installation complete. Next: linux/apply_to_local.sh"
}

main "$@"

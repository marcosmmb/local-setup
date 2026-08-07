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
#
# Returns non-zero without touching $dest if the key cannot be fetched. Note
# that `gpg --dearmor -o FILE` creates FILE even when it rejects its input, so
# the download goes to a scratch directory and is only installed once it parses
# as a keyring -- an interrupted download must not leave behind a truncated file
# that every later run then skips over, leaving apt permanently at NO_PUBKEY.
add_key() {
	local url="$1" dest="$2"
	if [ -s "$dest" ] && gpg --show-keys --with-colons "$dest" >/dev/null 2>&1; then
		return 0
	fi
	local tmpdir
	tmpdir="$(mktemp -d)"
	if ! curl -fsSL "$url" | gpg --dearmor -o "$tmpdir/key.gpg" 2>/dev/null \
		|| ! [ -s "$tmpdir/key.gpg" ] \
		|| ! gpg --show-keys --with-colons "$tmpdir/key.gpg" >/dev/null 2>&1; then
		rm -rf "$tmpdir"
		return 1
	fi
	sudo install -m 0755 -d "$(dirname "$dest")"
	sudo install -m 0644 "$tmpdir/key.gpg" "$dest"
	rm -rf "$tmpdir"
}

# name content -- write /etc/apt/sources.list.d/<name> if not already present.
add_source() {
	local name="$1" content="$2"
	local stem="${name%.*}"
	# apt reads both the one-line .list and the deb822 .sources format. A repo
	# already configured as <stem>.sources must not be re-added as <stem>.list,
	# or apt reports a duplicate entry and fetches the same index twice.
	if [ -f "/etc/apt/sources.list.d/$stem.list" ] \
		|| [ -f "/etc/apt/sources.list.d/$stem.sources" ]; then
		return 0
	fi
	echo "$content" | sudo tee "/etc/apt/sources.list.d/$name" > /dev/null
	echo "    added $name"
}

# key_url keyring name content -- add a repository, but only once its signing
# key is in place. Adding the source without the key would leave `apt-get
# update` failing for every repository, which under `set -e` aborts the whole
# bootstrap; skipping one vendor only costs that vendor's packages.
add_repo() {
	local url="$1" keyring="$2" name="$3" content="$4"
	if ! add_key "$url" "$keyring"; then
		warn "skipping ${name%.*}: could not fetch its signing key from $url"
		return 0
	fi
	add_source "$name" "$content"
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
	add_repo "https://download.docker.com/linux/ubuntu/gpg" /etc/apt/keyrings/docker.gpg \
		docker.list \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable"

	# VS Code
	add_repo "https://packages.microsoft.com/keys/microsoft.asc" /usr/share/keyrings/microsoft.gpg \
		vscode.list \
		"deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"

	# Brave
	add_repo "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
		/usr/share/keyrings/brave-browser-archive-keyring.gpg \
		brave-browser-release.list \
		"deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"

	# Google Cloud CLI
	add_repo "https://packages.cloud.google.com/apt/doc/apt-key.gpg" /usr/share/keyrings/cloud.google.gpg \
		google-cloud-sdk.list \
		"deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main"

	# HashiCorp (terraform)
	add_repo "https://apt.releases.hashicorp.com/gpg" /usr/share/keyrings/hashicorp-archive-keyring.gpg \
		hashicorp.list \
		"deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $CODENAME main"

	# NodeSource (Node 24.x)
	add_repo "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" /etc/apt/keyrings/nodesource.gpg \
		nodesource.list \
		"deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main"

	# MongoDB database tools
	add_repo "https://www.mongodb.org/static/pgp/server-8.0.asc" /usr/share/keyrings/mongodb-server-8.0.gpg \
		mongodb-org-8.0.list \
		"deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu $LTS_CODENAME/mongodb-org/8.0 multiverse"

	# Slack, via packagecloud's signing key -- without signed-by= the repository
	# is unauthenticated and `apt-get update` refuses it outright.
	add_repo "https://packagecloud.io/slacktechnologies/slack/gpgkey" /usr/share/keyrings/slack.gpg \
		slack.list \
		"deb [signed-by=/usr/share/keyrings/slack.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ jessie main"

	# Spotify
	add_repo "https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg" \
		/usr/share/keyrings/spotify.gpg \
		spotify.list \
		"deb [signed-by=/usr/share/keyrings/spotify.gpg] https://repository.spotify.com stable non-free"

	# Obsidian ships as a .deb rather than a repo; see install_obsidian below.

	sudo apt-get update -qq
}

install_apt_packages() {
	local f="$MANIFEST_DIR/apt-install.txt"
	[ -f "$f" ] || { warn "no apt-install.txt; skipping"; return 0; }
	log "Installing apt packages"

	# Read into an array rather than an unquoted $(...): the manifest is data,
	# and a `*` in it would otherwise be glob-expanded into local filenames and
	# handed to apt as package names.
	local pkgs=() line
	while IFS= read -r line; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[ -n "$line" ] || continue
		pkgs+=("$line")
	done < "$f"
	[ ${#pkgs[@]} -gt 0 ] || { warn "apt-install.txt is empty; skipping"; return 0; }

	sudo apt-get install -y "${pkgs[@]}" && return 0

	# One unresolvable name must not abort the bootstrap before any dotfiles or
	# GNOME settings are applied: some packages exist only on certain releases,
	# and others come from a third-party repo that setup_repositories may have
	# skipped. Retry individually so the rest still lands.
	warn "batch install failed; retrying package by package"
	local p failed=()
	for p in "${pkgs[@]}"; do
		sudo apt-get install -y -qq "$p" >/dev/null 2>&1 || failed+=("$p")
	done
	[ ${#failed[@]} -eq 0 ] || warn "could not install: ${failed[*]}"
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
	# Pin the host: the release URL is scraped out of an unauthenticated API
	# response, so accept only one that points at Obsidian's own downloads.
	url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
		| grep -oE 'https://github\.com/obsidianmd/obsidian-releases/releases/download/[^"]*amd64\.deb' \
		| head -1)"
	[ -n "$url" ] || { warn "could not resolve Obsidian release URL"; return 0; }

	# A private scratch directory rather than a fixed /tmp path: /tmp is
	# world-writable, so a predictable name lets any local user pre-create a
	# symlink, or swap the file between the download and `apt-get install`,
	# which unpacks it and runs its maintainer scripts as root.
	local tmpdir
	tmpdir="$(mktemp -d)"
	local deb="$tmpdir/obsidian.deb"
	if curl -fsSL "$url" -o "$deb" && dpkg-deb --info "$deb" >/dev/null 2>&1; then
		sudo apt-get install -y "$deb"
	else
		warn "Obsidian download failed or is not a valid .deb; skipping"
	fi
	rm -rf "$tmpdir"
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
	local zsh_path
	zsh_path="$(command -v zsh)" || { warn "zsh not installed; leaving the default shell alone"; return 0; }
	[ "$SHELL" = "$zsh_path" ] && return 0
	log "Setting zsh as the default shell"
	# chsh authenticates over stdin. If this is running without a terminal --
	# piped from curl, or from CI -- that prompt gets EOF and fails, which must
	# not take the rest of the bootstrap down with it.
	if ! chsh -s "$zsh_path"; then
		warn "could not change the default shell; run this by hand: chsh -s $zsh_path"
	fi
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

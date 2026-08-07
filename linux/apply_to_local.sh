#!/usr/bin/env bash
#
# Apply the configuration stored in this repository to the local machine.
#
# Existing files are backed up to ~/.local-setup-backup/<timestamp>/ before
# being overwritten, so this is safe to run on a machine that is already set up.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINUX_DIR="$REPO_DIR/linux"
HOME_DIR="$LINUX_DIR/home"
BACKUP_DIR="$HOME/.local-setup-backup/$(date +%Y%m%d-%H%M%S)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[skip]\033[0m %s\n' "$*"; }

backup() {
	local target="$1" rel="${1#"$HOME"/}"
	[ -e "$target" ] || return 0
	mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
	cp -r "$target" "$BACKUP_DIR/$rel"
}

install_path() {
	local src="$1" dest="$2"
	backup "$dest"
	mkdir -p "$(dirname "$dest")"
	if [ -d "$src" ]; then
		rm -rf "$dest"
		cp -r "$src" "$dest"
	else
		cp "$src" "$dest"
	fi
	echo "    ${dest#"$HOME"/}"
}

apply_home() {
	log "Installing dotfiles into \$HOME"
	# Top-level dotfiles.
	find "$HOME_DIR" -maxdepth 1 -type f -name '.*' -print0 \
		| while IFS= read -r -d '' src; do
			install_path "$src" "$HOME/$(basename "$src")"
		done
	# Everything under .config, preserving relative layout.
	if [ -d "$HOME_DIR/.config" ]; then
		find "$HOME_DIR/.config" -mindepth 1 -maxdepth 1 -print0 \
			| while IFS= read -r -d '' src; do
				install_path "$src" "$HOME/.config/$(basename "$src")"
			done
	fi
}

apply_dconf() {
	local f="$LINUX_DIR/dconf/gnome.ini"
	[ -f "$f" ] || { warn "no dconf dump to load"; return 0; }
	log "Loading GNOME settings from dconf/gnome.ini"
	dconf load / < "$f"
	echo "    loaded $(grep -c '^\[' "$f") sections (log out and back in to apply fully)"
}

apply_xmodmap() {
	[ -f "$HOME/.Xmodmap" ] || return 0
	if command -v xmodmap >/dev/null && [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then
		log "Applying ~/.Xmodmap"
		xmodmap "$HOME/.Xmodmap"
	else
		warn "~/.Xmodmap installed but not applied (needs an X11 session; Wayland uses input-remapper)"
	fi
}

apply_vscode_extensions() {
	local f="$LINUX_DIR/manifests/vscode-extensions.txt"
	[ -f "$f" ] || return 0
	command -v code >/dev/null || { warn "code not installed; skipping extensions"; return 0; }
	log "Installing VS Code extensions"
	while read -r ext; do
		[ -n "$ext" ] || continue
		code --install-extension "$ext" --force >/dev/null && echo "    $ext"
	done < "$f"
}

apply_gnome_extensions() {
	local f="$LINUX_DIR/manifests/gnome-extensions.txt"
	[ -f "$f" ] || return 0
	command -v gnome-extensions >/dev/null || return 0
	log "Enabling GNOME extensions"
	while read -r ext; do
		[ -n "$ext" ] || continue
		if gnome-extensions info "$ext" >/dev/null 2>&1; then
			gnome-extensions enable "$ext" && echo "    $ext"
		else
			warn "$ext not installed (get it from extensions.gnome.org)"
		fi
	done < "$f"
}

main() {
	log "Applying configuration from $REPO_DIR"
	log "Backups will be written to $BACKUP_DIR"
	apply_home
	apply_dconf
	apply_xmodmap
	apply_vscode_extensions
	apply_gnome_extensions
	echo
	log "Done. See docs/manual-checklist.md for credentials that must be restored by hand."
}

main "$@"

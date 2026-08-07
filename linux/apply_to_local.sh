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

# Merge the repository's copy of a JSONC settings file into the live one.
#
# redact_jsonc.py strips machine-local values out of these before they are
# committed. Copying the result back verbatim would overwrite the real values
# with the placeholder string -- and change their JSON type, which breaks the
# extensions that read them -- so placeholder keys keep whatever the machine
# already has instead.
MERGED_FILES=(
	".config/Code/User/settings.json"
)

is_merged_file() {
	local rel="$1" m
	for m in "${MERGED_FILES[@]}"; do
		[ "$rel" = "$m" ] && return 0
	done
	return 1
}

install_file() {
	local src="$1" dest="$2" rel="${2#"$HOME"/}"
	backup "$dest"
	mkdir -p "$(dirname "$dest")"
	if is_merged_file "$rel"; then
		if python3 "$LINUX_DIR/lib/merge_jsonc.py" "$src" "$dest" > "$dest.new"; then
			mv "$dest.new" "$dest"
			echo "    $rel (merged; machine-local values kept)"
			return 0
		fi
		rm -f "$dest.new"
		warn "$rel: merge failed, left the existing file alone"
		return 0
	fi
	cp "$src" "$dest"
	echo "    $rel"
}

# Copy a directory in file by file rather than replacing it wholesale.
#
# The repository mirror is deliberately partial -- .config/gh holds only
# config.yml because hosts.yml is the OAuth token, and .config/Code holds only
# User/settings.json and User/keybindings.json -- so `rm -rf` on the destination
# would delete the live credentials and editor state that were never captured.
install_tree() {
	local src="$1" dest="$2"
	find "$src" -type f -print0 \
		| while IFS= read -r -d '' f; do
			install_file "$f" "$dest/${f#"$src"/}"
		done
}

install_path() {
	local src="$1" dest="$2"
	if [ -d "$src" ]; then
		install_tree "$src" "$dest"
	else
		install_file "$src" "$dest"
	fi
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
	command -v dconf >/dev/null || { warn "dconf not installed; skipping GNOME settings"; return 0; }
	log "Loading GNOME settings from dconf/gnome.ini"

	# Filter on the way in as well as on the way out. replicate_from_local.sh
	# already drops the keys in lib/dconf-exclude-keys.txt, but a dump captured
	# before that -- or edited by hand -- must not be able to turn off this
	# machine's screen lock just because it was committed.
	local skipkeys
	skipkeys="$(grep -vE '^\s*(#|$)' "$LINUX_DIR/lib/dconf-exclude-keys.txt")"
	awk -v skipkeys="$skipkeys" '
		BEGIN {
			n = split(skipkeys, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) if (parts[i] != "") drop[parts[i]] = 1
		}
		/^\[/ { section = substr($0, 2, length($0) - 2); print; next }
		{
			key = $0
			sub(/=.*/, "", key)
			if (key != "" && ((section "/" key) in drop)) { skipped++; next }
			print
		}
		END { if (skipped) print "    skipped " skipped " screen-lock/suspend key(s)" > "/dev/stderr" }
	' "$f" | dconf load /

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

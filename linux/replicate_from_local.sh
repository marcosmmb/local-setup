#!/usr/bin/env bash
#
# Capture this machine's configuration into the repository.
#
# Everything copied here is chosen by the explicit allowlists below. Nothing is
# globbed out of $HOME, because this repository is public -- see
# docs/manual-checklist.md for the things that are deliberately NOT captured.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINUX_DIR="$REPO_DIR/linux"
HOME_DIR="$LINUX_DIR/home"
CONFIG_DIR="$HOME_DIR/.config"
MANIFEST_DIR="$LINUX_DIR/manifests"
DCONF_DIR="$LINUX_DIR/dconf"

# Dotfiles copied straight from $HOME.
HOME_FILES=(
	.bashrc
	.gitconfig
	.profile
	.Xmodmap
	.xmodmaprc
	.zshrc
)

# Whole directories under ~/.config that are safe to copy verbatim.
#
# Deliberately absent: nautilus, org.gnome.Ptyxis and tiling-assistant. Those
# hold only session state (open tabs, restored window layouts) -- their real
# settings live in dconf and are captured by dump_dconf below.
CONFIG_DIRS=(
	btop
	input-remapper-2
)

# Individual files under ~/.config.
CONFIG_FILES=(
	mimeapps.list
	monitors.xml
	user-dirs.dirs
	# gh's config.yml holds preferences; hosts.yml holds the OAuth token.
	gh/config.yml
	# VS Code: settings only, never globalStorage/ or sync/.
	"Code/User/keybindings.json"
)

# JSONC files copied through lib/redact_jsonc.py rather than verbatim, because
# extensions persist API tokens and database connection strings into them.
REDACTED_CONFIG_FILES=(
	"Code/User/settings.json"
)

# dconf subtrees to skip: these carry account identities rather than settings.
DCONF_EXCLUDE='^(org/gnome/nm-applet|org/gnome/evolution-data-server)'

# Individual dconf keys to skip, as <section>/<key>. Shared with
# apply_to_local.sh so a key is dropped on the way out and on the way back in.
DCONF_EXCLUDE_KEYS="$(grep -vE '^\s*(#|$)' "$LINUX_DIR/lib/dconf-exclude-keys.txt")"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[skip]\033[0m %s\n' "$*"; }

copy_home_files() {
	log "Copying dotfiles from \$HOME"
	mkdir -p "$HOME_DIR"
	for f in "${HOME_FILES[@]}"; do
		if [ -f "$HOME/$f" ]; then
			cp "$HOME/$f" "$HOME_DIR/$f"
			echo "    $f"
		else
			warn "~/$f not found"
		fi
	done
}

copy_config() {
	log "Copying ~/.config entries"
	mkdir -p "$CONFIG_DIR"
	for d in "${CONFIG_DIRS[@]}"; do
		if [ -d "$HOME/.config/$d" ]; then
			rm -rf "${CONFIG_DIR:?}/$d"
			cp -r "$HOME/.config/$d" "$CONFIG_DIR/$d"
			echo "    .config/$d/"
		else
			warn "~/.config/$d not found"
		fi
	done
	for f in "${CONFIG_FILES[@]}"; do
		if [ -f "$HOME/.config/$f" ]; then
			mkdir -p "$CONFIG_DIR/$(dirname "$f")"
			cp "$HOME/.config/$f" "$CONFIG_DIR/$f"
			echo "    .config/$f"
		else
			warn "~/.config/$f not found"
		fi
	done
	for f in "${REDACTED_CONFIG_FILES[@]}"; do
		if [ -f "$HOME/.config/$f" ]; then
			mkdir -p "$CONFIG_DIR/$(dirname "$f")"
			# Fail loudly rather than committing an unredacted file.
			if ! python3 "$LINUX_DIR/lib/redact_jsonc.py" "$HOME/.config/$f" \
				> "$CONFIG_DIR/$f.tmp"; then
				rm -f "$CONFIG_DIR/$f.tmp"
				echo "ERROR: could not redact ~/.config/$f -- not copied" >&2
				exit 1
			fi
			mv "$CONFIG_DIR/$f.tmp" "$CONFIG_DIR/$f"
			echo "    .config/$f (redacted)"
		else
			warn "~/.config/$f not found"
		fi
	done
	# VS Code snippets are a directory but live under Code/User.
	if [ -d "$HOME/.config/Code/User/snippets" ]; then
		rm -rf "$CONFIG_DIR/Code/User/snippets"
		cp -r "$HOME/.config/Code/User/snippets" "$CONFIG_DIR/Code/User/snippets"
		echo "    .config/Code/User/snippets/"
	fi
}

dump_dconf() {
	log "Dumping dconf (GNOME settings, keybindings, extension state)"
	mkdir -p "$DCONF_DIR"
	# Drop excluded sections along with the key/value block that follows each
	# one, then drop the individually excluded keys.
	dconf dump / | awk -v skip="$DCONF_EXCLUDE" -v skipkeys="$DCONF_EXCLUDE_KEYS" '
		BEGIN {
			n = split(skipkeys, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) if (parts[i] != "") drop[parts[i]] = 1
		}
		/^\[/ {
			section = substr($0, 2, length($0) - 2)
			inskip = (section ~ skip)
		}
		inskip { next }
		/^\[/ { print; next }
		{
			key = $0
			sub(/=.*/, "", key)
			if (key != "" && ((section "/" key) in drop)) next
			print
		}
	' > "$DCONF_DIR/gnome.ini"
	echo "    dconf/gnome.ini ($(grep -c '^\[' "$DCONF_DIR/gnome.ini") sections)"
}

write_manifests() {
	log "Writing package manifests"
	mkdir -p "$MANIFEST_DIR"

	apt-mark showmanual | sort > "$MANIFEST_DIR/apt-manual.txt"
	echo "    apt-manual.txt ($(wc -l < "$MANIFEST_DIR/apt-manual.txt") packages)"

	if command -v snap >/dev/null; then
		snap list | awk 'NR > 1 { print $1 (($6 == "classic") ? " --classic" : "") }' \
			| sort > "$MANIFEST_DIR/snap.txt"
		echo "    snap.txt ($(wc -l < "$MANIFEST_DIR/snap.txt") snaps)"
	fi

	if command -v code >/dev/null; then
		code --list-extensions | sort > "$MANIFEST_DIR/vscode-extensions.txt"
		echo "    vscode-extensions.txt ($(wc -l < "$MANIFEST_DIR/vscode-extensions.txt") extensions)"
	fi

	if command -v gnome-extensions >/dev/null; then
		gnome-extensions list | sort > "$MANIFEST_DIR/gnome-extensions.txt"
		echo "    gnome-extensions.txt ($(wc -l < "$MANIFEST_DIR/gnome-extensions.txt") extensions)"
	fi

	if [ -d "$HOME/go/bin" ]; then
		# Record the binaries present; install.sh maps them to module paths.
		find "$HOME/go/bin" -maxdepth 1 -type f -printf '%f\n' | sort \
			> "$MANIFEST_DIR/go-tools.txt"
		echo "    go-tools.txt ($(wc -l < "$MANIFEST_DIR/go-tools.txt") tools)"
	fi

	if command -v npm >/dev/null; then
		npm ls -g --depth=0 --parseable 2>/dev/null \
			| tail -n +2 | xargs -r -n1 basename | sort > "$MANIFEST_DIR/npm-global.txt"
		echo "    npm-global.txt ($(wc -l < "$MANIFEST_DIR/npm-global.txt") packages)"
	fi

	if [ -d "$HOME/Applications" ]; then
		find "$HOME/Applications" -maxdepth 1 -iname '*.AppImage' -printf '%f\n' | sort \
			> "$MANIFEST_DIR/appimages.txt"
		echo "    appimages.txt ($(wc -l < "$MANIFEST_DIR/appimages.txt") images)"
	fi
}

copy_apt_sources() {
	log "Copying apt source definitions"
	local dest="$MANIFEST_DIR/apt-sources"
	rm -rf "$dest"
	mkdir -p "$dest"
	# Skip distro defaults and curtin's installer leftovers; keep third-party repos.
	#
	# This directory is the one thing here that is globbed rather than
	# allowlisted, because the point is to record whatever repositories the
	# machine actually has. Managed and commercial repositories routinely carry
	# a per-machine credential in the URI (https://<token>@repo.vendor.com/...)
	# or in a deb822 auth field, so strip those on the way in rather than
	# publishing them.
	local name
	for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
		[ -f "$f" ] || continue
		name="$(basename "$f")"
		case "$name" in
			ubuntu.sources|ubuntu.sources.curtin.orig) continue ;;
		esac
		sed -E \
			-e 's,://[^/[:space:]@]+(:[^/[:space:]@]*)?@,://<redacted>@,g' \
			-e 's,^([[:space:]]*(Password|Passphrase|Token|Authorization)[[:space:]]*:).*,\1 <redacted>,I' \
			"$f" > "$dest/$name"
		if cmp -s "$f" "$dest/$name"; then
			echo "    $name"
		else
			echo "    $name (credentials redacted)"
		fi
	done
}

record_system_info() {
	log "Recording system reference info"
	{
		echo "# Captured from $(hostname) -- reference only, not replayed by apply_to_local.sh"
		echo
		echo "## OS"
		grep PRETTY_NAME /etc/os-release
		echo "kernel: $(uname -r)"
		echo "shell:  $SHELL"
		echo
		echo "## Locale"
		echo "lang: ${LANG:-unset}"
	} > "$LINUX_DIR/system-info.md"
	echo "    system-info.md"
}

main() {
	log "Replicating local configuration into $REPO_DIR"
	copy_home_files
	copy_config
	dump_dconf
	write_manifests
	copy_apt_sources
	record_system_info
	echo
	log "Done. Review 'git status' before committing -- this repository is public."
}

main "$@"

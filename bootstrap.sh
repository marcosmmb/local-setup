#!/usr/bin/env bash
#
# One command to take a freshly installed Ubuntu machine to a working setup.
#
#   git clone https://github.com/marcosmmb/local-setup.git
#   cd local-setup && ./bootstrap.sh
#
# Safe to re-run. Existing dotfiles are backed up before being overwritten.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;32m===>\033[0m \033[1m%s\033[0m\n' "$*"; }

case "$(uname -s)" in
	Linux)
		log "Step 1/2 -- installing packages"
		"$REPO_DIR/linux/install.sh"

		log "Step 2/2 -- applying configuration"
		"$REPO_DIR/linux/apply_to_local.sh"
		;;
	Darwin)
		log "Step 1/2 -- installing packages"
		"$REPO_DIR/osx/install.sh"

		log "Step 2/2 -- applying configuration"
		"$REPO_DIR/osx/apply_to_local.sh"
		;;
	*)
		echo "Unsupported platform: $(uname -s)" >&2
		exit 1
		;;
esac

log "Bootstrap complete"
cat <<-EOF

	Two things left, both by hand:

	  1. Work through docs/manual-checklist.md -- SSH keys, GPG, and every
	     credential this repository deliberately does not store.

	  2. Log out and back in, so that the docker group membership, the default
	     shell, and the GNOME settings all take effect.
EOF

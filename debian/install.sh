#!/bin/sh
#
# Compatibility shim.
#
# The Debian/Ubuntu setup now lives in linux/, which handles third-party apt
# repositories, snaps, dotfiles and GNOME settings rather than a flat list of
# `apt install` calls. This file stays so the hosted one-liner in the README
# keeps working:
#
#   curl -fsS https://marcosmmb.github.io/local-setup/debian/install.sh | sh
#
set -eu

REPO_URL="https://github.com/marcosmmb/local-setup.git"
CLONE_DIR="${LOCAL_SETUP_DIR:-$HOME/local-setup}"

echo "The Debian installer now lives in linux/ and needs the full repository."

if [ ! -d "$CLONE_DIR/.git" ]; then
	echo "Cloning $REPO_URL into $CLONE_DIR"
	command -v git >/dev/null 2>&1 || sudo apt-get install -y git
	git clone "$REPO_URL" "$CLONE_DIR"
else
	echo "Using existing clone at $CLONE_DIR"
	git -C "$CLONE_DIR" pull --ff-only
fi

echo "Running $CLONE_DIR/bootstrap.sh"
exec "$CLONE_DIR/bootstrap.sh"

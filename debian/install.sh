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
	# bootstrap.sh runs sudo throughout -- apt sources, keyrings, usermod. Only
	# hand it a checkout that really is this repository: "a directory named
	# local-setup exists" is not evidence of that, and $LOCAL_SETUP_DIR can name
	# any directory at all.
	origin="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || true)"
	case "$origin" in
		"$REPO_URL"|"${REPO_URL%.git}"|\
		ssh://git@github.com/marcosmmb/local-setup.git|\
		ssh://git@github.com/marcosmmb/local-setup|\
		git@github.com:marcosmmb/local-setup.git|\
		git@github.com:marcosmmb/local-setup) ;;
		*)
			echo "Refusing to run $CLONE_DIR/bootstrap.sh." >&2
			echo "Its origin is '${origin:-none}', not $REPO_URL." >&2
			echo "Move that directory aside, or point LOCAL_SETUP_DIR somewhere else." >&2
			exit 1
			;;
	esac
	echo "Using existing clone at $CLONE_DIR"
	git -C "$CLONE_DIR" pull --ff-only
fi

echo "Running $CLONE_DIR/bootstrap.sh"
# Under `curl ... | sh` stdin is the fetch pipe, already at EOF. bootstrap.sh
# runs chsh and sudo, both of which prompt, so give it the terminal back.
if [ -r /dev/tty ]; then
	exec < /dev/tty
fi
exec "$CLONE_DIR/bootstrap.sh"

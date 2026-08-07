# local-setup

Configuration files and scripts for my local machines, so that reformatting a
disk or moving to a new laptop is a scripted step rather than a week of
remembering what was installed.

> [!WARNING]
> **This repository is public.** No credentials, private keys or tokens belong
> here. See [`docs/manual-checklist.md`](docs/manual-checklist.md) for what is
> deliberately left out and how to restore it by hand.

## Quick start on a new machine

```bash
git clone https://github.com/marcosmmb/local-setup.git ~/local-setup
cd ~/local-setup && ./bootstrap.sh
```

`bootstrap.sh` detects the platform, installs packages, then applies the stored
configuration. Afterwards, work through `docs/manual-checklist.md` and log out
and back in.

The hosted one-liner still works and now clones the repository first:

```bash
curl -fsS https://marcosmmb.github.io/local-setup/debian/install.sh | sh
```

## Everyday use

```bash
make help              # list all targets
make fromlocal-linux   # capture this machine's config into the repo (linux)
make tolocal-linux     # apply the repo's config to this machine (linux)
make fromlocal-osx     # capture this machine's config into the repo (osx)
make tolocal-osx       # apply the repo's config to this machine (osx)
make hooks             # enable secret scanning (run once per clone)
make scan              # scan history for secrets
```

The capture/apply pair is the core loop: change something on the machine, run
`make fromlocal-linux`, review `git status`, commit.

## Layout

```
bootstrap.sh              Entry point: install + apply, platform-aware
linux/
  install.sh              apt repos & keyrings, packages, snaps, oh-my-zsh, Go tools
  replicate_from_local.sh Machine -> repo  (allowlist-driven)
  apply_to_local.sh       Repo -> machine  (backs up before overwriting)
  home/                   Dotfiles, laid out relative to $HOME
  manifests/              Package lists, extensions, apt source definitions
  dconf/gnome.ini         GNOME settings, keybindings, extension state
osx/                      The same pattern for macOS
docs/manual-checklist.md  Credentials and steps that cannot be automated
other/                    Odds and ends
```

Files under `home/` mirror their path relative to `$HOME`, so
`linux/home/.config/btop/btop.conf` installs to `~/.config/btop/btop.conf`.

## What actually gets captured

| | |
|---|---|
| Dotfiles | `.zshrc` `.bashrc` `.profile` `.gitconfig` `.Xmodmap` `.xmodmaprc` |
| `~/.config` | btop, input-remapper, nautilus, Ptyxis, tiling-assistant, mimeapps, monitors.xml, VS Code settings & keybindings, `gh/config.yml` |
| GNOME | Full `dconf` dump — keybindings, dock, tweaks, extension settings |
| Packages | apt (curated + full record), snap, VS Code extensions, GNOME extensions, Go tools, npm globals |
| apt repos | Third-party `.list`/`.sources` files, with keyring URLs re-derived in `install.sh` |

The two that matter most and are easiest to forget are the **dconf dump** and
the **apt repository/keyring setup** — reinstalling packages is easy, but
recreating 200 lines of GNOME state and a dozen signed repositories by hand is
not.

## Not captured, on purpose

Private keys, `~/.gnupg`, `~/.kube`, `~/.docker/config.json`, `~/.config/gcloud`,
`~/.claude.json`, `gh`'s `hosts.yml`, Terraform credentials, browser profiles
and shell history.

Three layers keep them out:

1. `replicate_from_local.sh` copies only from an explicit allowlist — it never
   globs `$HOME`.
2. `.gitignore` denies secret-shaped paths as a backstop against manual `git add`.
3. A `gitleaks` pre-commit hook (`make hooks`) blocks commits that slip through.

Hardware-specific drivers (Dell Somerville/Remoraid, DisplayLink, IPU6 camera)
and IT-managed agents (SentinelOne, osquery) are also skipped — `install.sh`
prints the list and explains why.

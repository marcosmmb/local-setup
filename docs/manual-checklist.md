# Manual checklist

Everything in this file is **deliberately not stored in this repository**, because
`marcosmmb/local-setup` is public. Work through it after running `bootstrap.sh`
on a new machine.

Order matters: SSH and GitHub auth come first, because the rest of the checklist
assumes you can clone private repositories.

---

## 1. SSH keys

Not recoverable from anywhere but a backup — if you have no copy, you must
generate a new key and re-register it everywhere.

```bash
# Restore from your backup, or generate a new one:
ssh-keygen -t ed25519 -C "marcos@tigera.io"
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519
```

Then re-register the public key with:

- [ ] GitHub — <https://github.com/settings/keys>
- [ ] Any servers in your old `~/.ssh/config` (the macOS side of this repo has
      `osx/home/ssh` as a starting point for host entries)

`~/.gitconfig` sets `url."ssh://git@github.com/".insteadOf https://github.com/`,
so every GitHub clone goes over SSH — nothing works until this step is done.

## 2. GPG keys

```bash
# On the old machine:
gpg --export-secret-keys --armor <KEY_ID> > private.asc
# On the new machine:
gpg --import private.asc && shred -u private.asc
```

- [ ] Imported, and `gpg --list-secret-keys` shows the key
- [ ] Trust level restored (`gpg --edit-key <KEY_ID>` → `trust` → `5`)

## 3. GitHub CLI

`~/.config/gh/config.yml` is restored by `apply_to_local.sh`; the token in
`hosts.yml` is not. Applying does not delete an existing `hosts.yml` either —
it merges the repository's files into `~/.config` rather than replacing whole
directories — so on a machine that is already authenticated there is nothing to
do here.

```bash
gh auth login
```

- [ ] `gh auth status` is clean (this also re-enables the git credential helper
      that `.gitconfig` points at)

## 4. Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <project>
```

- [ ] User credentials
- [ ] Application-default credentials
- [ ] `gke-gcloud-auth-plugin` present (installed by `install.sh`)

## 5. Kubernetes

`~/.kube/` holds cluster certificates and tokens and is never committed.

- [ ] Re-fetch cluster contexts (`gcloud container clusters get-credentials …`)
- [ ] Restore any standalone kubeconfigs under `~/kube/`

> Note: `kubectl` uses `~/.kube/config` as normal. To run against the
> kubeconfig a repository drops in `.local/`, use the `kubelocal` function from
> `.zshrc`/`.bashrc`, which prints the path it picked up.
>
> These shells used to alias `kubectl` itself to
> `KUBECONFIG=./.local/kubeconfig kubectl`. A `$PWD`-relative KUBECONFIG lets
> whatever directory you happen to be in supply the cluster credentials, so
> `cd`-ing into an untrusted checkout that ships a `.local/kubeconfig` handed
> kubectl that file — and a kubeconfig can run arbitrary commands through
> `users[].user.exec`.

## 6. Docker

```bash
docker login
```

- [ ] Registry auth (`~/.docker/config.json`)
- [ ] `docker ps` works without sudo (needs a re-login after `install.sh` adds
      you to the `docker` group)

## 7. Terraform

- [ ] `~/.terraform.d/credentials.tfrc.json` restored, or `terraform login`

## 8. AI tooling

Config files hold API keys and OAuth tokens, so none are committed.

- [ ] Claude Code — `claude` then `/login`
- [ ] Codex / Copilot — sign in through their respective CLIs
- [ ] MCP servers in `~/.claude.json` re-authenticated

## 9. Applications that need a login

- [ ] Slack (workspace: Tigera)
- [ ] Zoom
- [ ] Spotify
- [ ] Brave — sync chain, or sign in
- [ ] Obsidian — point at your vault; note the vault itself is not in this repo

## 10. Corporate / IT-managed

Do **not** install these by hand — ask IT to re-enroll the machine:

- [ ] `sentinelagent` (SentinelOne EDR)
- [ ] `amagent`
- [ ] `fleet-osquery`
- [ ] Any MDM profile or disk-encryption escrow

## 11. Hardware-specific

Only relevant on the same Dell Pro Max 14 (Somerville Remoraid) hardware:

- [ ] Fingerprint reader enrolled (`fprintd-enroll`)
- [ ] DisplayLink driver, if you use the dock
- [ ] IPU6 camera stack (`v4l2-relayd`, `libcamera`) — normally pulled in by the
      OEM metapackage automatically
- [ ] `~/.config/monitors.xml` matches your actual monitor layout; delete it if
      the new machine has a different display setup

## 12. Things this repo intentionally does not back up

These are data, not configuration — keep them in your normal backup:

- `~/Documents/`, `~/Downloads/`, `~/Screenshots/`
- Obsidian vaults
- `~/go/pkg`, `~/.cache`, `~/.npm` (all regenerable)
- Shell history (`.zsh_history`, `.bash_history`)

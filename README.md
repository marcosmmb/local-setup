# local-setup
Repository to store configuration files and scripts for my local machines

## Debian

### Install Debian applications

From hosted script:

```bash
curl -fsS https://marcosmmb.github.io/local-setup/debian/install.sh | sh
```

From local repository:

```bash
make install-debian
```


## MacOS

### File organization
Files should be located starting from the home directory. For instance, on MacOS, first run `cd` and then paste the files following its relative path.


### Install MacOS applications

From hosted script:

```bash
curl -fsS https://marcosmmb.github.io/local-setup/osx/install.sh | sh
```

From local repository:

```bash
make install-osx
```


### Replicate files from local to repository
From root folder, run

```bash
make fromlocal
```


### Apply files from repository to local
From root folder, run

```bash
make tolocal
```

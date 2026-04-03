# Encrypted Secrets

This directory contains an age-encrypted archive of secret files (SSH keys, configs, etc.)
that are decrypted during installation with a single passphrase prompt.

## Prerequisites

- [age](https://github.com/FiloSottile/age) (installed automatically by the installer)

## How it works

1. `make-secrets.sh` bundles all secret files into a tar archive, encrypts it with `age -p`, and stores it as `secrets.tar.gz.age`
2. `manifest.txt` maps file destinations and permissions (used for both packing and extracting)
3. During `install.sh`, you're prompted once for the passphrase to decrypt and extract everything

## Adding or updating a secret

### 1. Add it to the manifest

Edit `secrets/manifest.txt`:

```
# format: name.age:~/destination/path:permissions
my_key.age:~/.ssh/my_key:600
```

The `name.age` field is only used as a label — all files are bundled into one archive.

### 2. Re-encrypt the bundle

```bash
./make-secrets.sh
```

This collects all files listed in the manifest from their destinations, bundles them into a tar, encrypts it with age, and writes `secrets/secrets.tar.gz.age`.

### 3. Commit

```bash
git add secrets/secrets.tar.gz.age secrets/manifest.txt
git commit -m "chore: update encrypted secrets bundle"
```

## Manifest format

Each line in `manifest.txt` follows the format:

```
label:~/destination/path:permissions
```

- Lines starting with `#` are comments
- Blank lines are ignored
- `~` is expanded to `$HOME`

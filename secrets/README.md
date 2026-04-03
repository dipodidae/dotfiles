# Encrypted Secrets

This directory contains age-encrypted secret files (SSH keys, GPG keys, etc.)
that are decrypted during installation with a passphrase prompt.

## Prerequisites

- [age](https://github.com/FiloSottile/age) (installed automatically by the installer)

## How it works

1. Secret files are encrypted with `age -p` (passphrase-based encryption)
2. The `manifest.txt` file maps encrypted files to their destinations
3. During `install.sh`, you're prompted for the passphrase to decrypt them

## Adding a new secret

### 1. Encrypt the file

```bash
age -p -o secrets/ssh_id_ed25519.age ~/.ssh/id_ed25519
```

You'll be prompted to enter (and confirm) a passphrase.

### 2. Add it to the manifest

Edit `secrets/manifest.txt` and add a line:

```
# format: encrypted_filename:destination_path:permissions
ssh_id_ed25519.age:~/.ssh/id_ed25519:600
```

### 3. Commit the encrypted file

```bash
git add secrets/ssh_id_ed25519.age secrets/manifest.txt
git commit -m "feat: add encrypted SSH key"
```

## Manifest format

Each line in `manifest.txt` follows the format:

```
filename.age:~/destination/path:permissions
```

- Lines starting with `#` are comments
- Blank lines are ignored
- `~` is expanded to `$HOME`

## Re-encrypting after key rotation

If you rotate a key, just re-encrypt the new version with the same passphrase:

```bash
age -p -o secrets/ssh_id_ed25519.age ~/.ssh/id_ed25519
```

Use the same passphrase across all files so you only need to enter it once during install.

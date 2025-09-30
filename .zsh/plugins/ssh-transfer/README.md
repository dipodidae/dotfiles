# ssh-transfer zsh plugin

This custom plugin ships with the dotfiles installer and exposes a single command:

```
transfer-ssh-keys user@host
```

Key features:

- Copies matching private/public SSH key pairs from `~/.ssh` to the remote user's `~/.ssh` directory.
- Never overwrites existing files on the remote side.
- Supports alternate ports via `--port <number>` and preview mode with `--dry-run`.
- Ensures secure permissions on the remote keys (600 for private, 644 for public).

Useful options:

- `transfer-ssh-keys user@host --dry-run` — list what would be copied without transferring.
- `transfer-ssh-keys user@host --port 2222` — connect over a non-default SSH port.

The command requires local `ssh` and `scp`, and it creates the remote `~/.ssh` directory if missing.

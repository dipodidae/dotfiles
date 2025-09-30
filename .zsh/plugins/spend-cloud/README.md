# SpendCloud Plugin for Zsh

A comprehensive oh-my-zsh compatible plugin for SpendCloud and Proactive Frame development workflow.

## Features

### Aliases
- **Navigation**: `sc`, `scapi`, `scui`, `pf`
- **VS Code**: `cui`, `capi`, `cpf`
- **Quick Start**: `devapi`

### Functions
- **`cluster`** - Manage SpendCloud cluster lifecycle and dev services
- **`migrate`** - Handle database migrations across multiple groups
- **`nuke`** - Destructive client cleanup tool (requires `ENABLE_NUKE=1`)

## Installation

### Automatic Installation (Recommended)

This plugin is automatically installed when you run the dotfiles installer:

```bash
cd ~/projects/dotfiles
./install.sh
```

The installer will:
1. Copy the plugin to `~/.oh-my-zsh/custom/plugins/spend-cloud/`
2. Set up all necessary files and permissions

After installation, simply uncomment `spend-cloud` in your `~/.zshrc` plugins array.

### Manual Installation

If you need to install manually, see [INSTALL.md](./INSTALL.md).

### Method 1: Via Plugins Array (Recommended)

1. Edit `~/.zshrc`
2. Uncomment `spend-cloud` in the plugins array:
   ```zsh
   plugins=(
     git
     zsh-autosuggestions
     # ...
     spend-cloud  # Uncomment this line
   )
   ```
3. Restart your shell or run: `exec zsh`

### Method 2: Runtime Toggle

Enable temporarily without editing `.zshrc`:
```zsh
enable-spend-cloud
```

To disable (requires shell restart for full unload):
```zsh
disable-spend-cloud
exec zsh
```

## Usage Examples

### Cluster Management

```zsh
# Start cluster and dev services
cluster

# Rebuild with fresh images
cluster --rebuild

# Stop all services
cluster stop

# View logs
cluster logs
cluster logs api

# Help
cluster help
```

### Database Migrations

```zsh
# Run all migration groups
migrate

# Run specific group
migrate group customers

# Debug mode (run each group separately)
migrate debug

# Status
migrate status

# Rollback
migrate rollback customers

# Help
migrate help
```

### Client Cleanup (DANGEROUS)

⚠️ **Requires `ENABLE_NUKE=1` environment variable**

```zsh
# Enable nuke functionality
export ENABLE_NUKE=1

# Analyze what would be deleted (safe)
nuke --verify clientname

# Actually delete (destructive!)
nuke clientname

# Interactive selection
nuke

# Help
nuke --help
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_NUKE` | (unset) | Must be set to `1` to allow `nuke` command |
| `MIGRATION_GROUP_ORDER` | `proactive_config,proactive-default,sharedStorage,customers` | Override default migration group order |
| `DB_USERNAME` | `root` | Database username for `nuke` |
| `DB_PASSWORD` | (empty) | Database password for `nuke` |
| `DB_SERVICES_HOST` | `mysql-service` | Database host for `nuke` |
| `NUKE_CONFIG_DB` | `spend-cloud-config` | Config database name for `nuke` |

## Requirements

- Docker
- `sct` (SpendCloud CLI)
- Oh My Zsh

## Safety Features

- **Duplicate Load Protection**: Won't reload if already active
- **Nuke Safeguards**:
  - Requires `ENABLE_NUKE=1` environment variable
  - Protected name blacklist
  - Dual confirmation prompts
  - Verify mode for safe analysis
- **Colorized Output**: Clear visual feedback (respects `NO_COLOR`)

## Logs

Development service logs are stored in:
```
~/.cache/spend-cloud/logs/
```

## Troubleshooting

### Plugin Not Loading

1. Check plugin path exists:
   ```zsh
   ls ~/.zsh/plugins/spend-cloud/spend-cloud.plugin.zsh
   ```

2. Verify custom plugin directory is in fpath:
   ```zsh
   echo $fpath | grep "\.zsh/plugins"
   ```

3. Check for syntax errors:
   ```zsh
   zsh -n ~/.zsh/plugins/spend-cloud/spend-cloud.plugin.zsh
   ```

### Commands Not Found

If `cluster`, `migrate`, or `nuke` are not found:
- Ensure plugin is uncommented in plugins array
- Restart shell: `exec zsh`
- Check if loaded: `echo $_SPEND_CLOUD_PLUGIN_LOADED`

### Alias Conflicts

If you experience alias conflicts with other plugins:
- Load `spend-cloud` after other plugins
- Check for conflicts: `alias | grep -E "cluster|migrate|nuke"`

## Contributing

This plugin follows the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with adaptations for zsh.

See `/.github/copilot-instructions.md` for coding standards.

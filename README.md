# Mac App Auto-Installer

Automate your Mac setup with YAML profiles. Install curated app collections for your role in minutes.

## Quick Start

```bash
# Install from a starter pack
macinstall apply starter-packs/developer-setup.yaml

# Preview what will be installed (dry run)
macinstall apply --dry-run starter-packs/developer-setup.yaml

# Apply only a specific category
macinstall apply --only apps.editors starter-packs/developer-setup.yaml

# Skip optional packages
macinstall apply --skip-optional starter-packs/developer-setup.yaml
```

## Starter Packs

| Pack | Best For |
|------|----------|
| `developer-setup.yaml` | Full-stack devs, DevOps, engineers |
| `designer-setup.yaml` | UI/UX, brand, and graphic designers |
| `content-creator-setup.yaml` | Video creators, podcasters, writers |
| `data-science-setup.yaml` | Data scientists, ML engineers, analysts |

---

## Building Your Own Profile

### 1. Create a YAML file

```yaml
profile:
  name: My Custom Setup
  description: Short description of this profile
  version: "1.0"
  tags: [custom]
```

### 2. Add prerequisites

Prerequisites run first and are required before anything else installs.

```yaml
prerequisites:
  - name: Homebrew
    check: brew --version          # Command to check if already installed
    install: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    required: true                 # Abort if this fails
```

### 3. Add apps

Group apps by category for readability. Each app needs a `method`.

```yaml
apps:
  my_category:
    - name: Visual Studio Code     # Human-readable name
      cask: visual-studio-code     # Homebrew cask identifier
      method: brew_cask            # Install method (see below)
      optional: true               # Skip with --skip-optional flag
      post_install:                # Commands to run after install
        - code --install-extension ms-python.python
```

### 4. Add CLI tools

```yaml
cli_tools:
  my_tools:
    - name: ripgrep
      formula: ripgrep
      method: brew
```

### 5. Validate and apply

```bash
macinstall validate my-profile.yaml
macinstall apply my-profile.yaml
```

---

## Supported Install Methods

| Method | Description | Required Field |
|--------|-------------|----------------|
| `brew` | Homebrew formula | `formula: <name>` |
| `brew_cask` | Homebrew cask (GUI apps) | `cask: <name>` |
| `mas` | Mac App Store | `mas_id: <numeric-id>` |
| `script` | Arbitrary shell script | `script: <command>` |
| `pip` | Python pip package | `package: <name>` |
| `npm_global` | Global npm package | `package: <name>` |
| `manual` | Prompts user with URL/instructions | `url: <download-url>` |

### Finding identifiers

```bash
# Find Homebrew cask name
brew search --cask "app name"

# Find Mac App Store ID (from the app's URL)
# https://apps.apple.com/app/id<ID-IS-HERE>

# Find Homebrew formula name
brew search "tool name"
```

### Method-specific options

**brew / brew_cask**
```yaml
- name: PostgreSQL
  formula: postgresql@16
  method: brew
  post_install:
    - brew services start postgresql@16
```

**mas** (requires `mas` CLI: `brew install mas`)
```yaml
- name: Xcode
  mas_id: 497799835
  method: mas
```

**script**
```yaml
- name: nvm
  method: script
  script: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  check: nvm --version          # If this succeeds, skip install
  post_install:
    - nvm install --lts
```

**manual**
```yaml
- name: Proprietary App
  method: manual
  url: https://example.com/download
  note: "Accept the license agreement during install"
```

---

## Profile Schema Reference

```yaml
profile:
  name: string           # Required
  description: string    # Optional
  version: string        # Optional, e.g. "1.0"
  tags: [string]         # Optional, for filtering

prerequisites:
  - name: string
    check: string        # Shell command; skip install if exit 0
    install: string      # Shell command to install
    required: bool       # Abort entire profile if this fails
    post_install: [string]

apps:
  <category_name>:       # Arbitrary category key for organization
    - name: string
      cask: string       # For brew_cask method
      formula: string    # For brew method
      mas_id: integer    # For mas method
      method: enum       # brew | brew_cask | mas | script | pip | npm_global | manual
      optional: bool     # Default: false
      note: string       # Shown to user during install
      post_install: [string]
      check: string      # Skip if this command exits 0

cli_tools:
  <category_name>:
    - name: string
      formula: string
      method: brew
      post_install: [string]

python_packages:
  <group_name>:
    - <package_name>
    - optional: bool     # Mark entire group as optional

npm_globals: [string]

system_prefs:
  - description: string  # Shown to user
    command: string      # defaults write or osascript command

recommendations:
  if_installed:
    - app: string        # App name or formula
      suggest: [string]  # List of apps/tools to recommend
```

---

## Troubleshooting

### Homebrew not found after install
```bash
# Add to your ~/.zshrc or ~/.bash_profile
eval "$(/opt/homebrew/bin/brew shellenv)"
source ~/.zshrc
```

### Mac App Store apps fail to install
- Ensure you're signed into the App Store: **App Store → Sign In**
- `mas` CLI must be installed: `brew install mas`
- Some apps require a prior purchase

### Cask install fails with "already installed"
```bash
brew reinstall --cask <cask-name>
# or force overwrite
brew install --cask --force <cask-name>
```

### Permission denied errors
```bash
# Fix Homebrew directory permissions
sudo chown -R $(whoami) /opt/homebrew
```

### Post-install commands not running
- Check that the command is available in your PATH
- Some post-install commands require a new shell session: `source ~/.zshrc`

### Rosetta 2 (Apple Silicon Macs)
Some older apps require Rosetta 2. Install it once:
```bash
softwareupdate --install-rosetta --agree-to-license
```

### Profile validation errors
```bash
macinstall validate --verbose my-profile.yaml
```

### Skip a failing package and continue
```bash
macinstall apply --skip-errors my-profile.yaml
```

### Log output for debugging
```bash
macinstall apply my-profile.yaml --log ~/install.log
```

---

## Contributing

To submit a new starter pack:
1. Fork the repo
2. Add your `.yaml` to `starter-packs/`
3. Test with `macinstall apply --dry-run your-pack.yaml`
4. Open a PR with a description of the target persona

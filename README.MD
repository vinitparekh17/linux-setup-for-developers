# Linux Development Environment Setup Script

A robust, modular Bash script to automate setting up a Linux development environment across multiple distributions. Features include enhanced error handling, interactive package selection, and support for custom configurations—all in a single, portable file.

## Features

- **Multi-Distro Support**: Works seamlessly on:
  - Ubuntu/Debian (`apt-get`)
  - Fedora/CentOS/RHEL (`dnf`)
  - Arch/Manjaro (`pacman`)
  - OpenSUSE (`zypper`)
- **Modular Design**: Organized with reusable functions (e.g., `install_package`, `rollback`) for easy maintenance.
- **Error Handling**: Exits on failure (`set -e`), logs to `~/devsetup_*.log`, and supports rollback of failed installs.
- **Interactive UI**: Uses `dialog` for a menu-driven experience; falls back to defaults in non-TTY environments (e.g., CI/CD, SSH).
- **Package Management**: Smart detection of installed packages and AUR helper support (`yay` with fallback to `paru`).
- **Customization**: Loads user preferences from `~/.config/devsetup/config.sh` (e.g., `AUR_HELPER`).

## Installed Tools

The script offers flexible installation categories via an interactive menu. Default non-TTY installs include:

### Developer Essentials
- [x] Git
- [x] Curl
- [x] Visual Studio Code (distro-specific: `code` or `visual-studio-code-bin`)

### Optional Tools (Menu-Selectable)
- [x] Wget
- [x] Htop
- [x] Neofetch
- [x] Vim
- [x] Neovim

*More categories (e.g., Docker, Go, Node.js) can be added by extending the script.*

## Prerequisites
- Bash 4.0+
- Internet connection
- `sudo` privileges
- Supported Linux distribution

## Usage

### Quick Start
Download and run:
```bash
curl -sSL https://raw.githubusercontent.com/vinitparekh17/linux-setup-for-developers/refs/heads/main/devsetup.sh -o devsetup.sh
chmod +x devsetup.sh
./devsetup.sh
```

> [!TIP]
> Review the script before running (less devsetup.sh) for security.

### Options
```bash
./devsetup.sh [-n] [-d] [-v] [-h]
  -n  Dry run: Simulate without changes
  -d  Developer mode: Enable extra tools (TBD)
  -v  Verbose: Detailed output
  -h  Help: Show usage
```

## What happens?
1. Detects your Linux distribution and package manager.
2. Installs dialog if missing (for interactive menus).
3. Prompts for category selection (or installs defaults in non-TTY mode).
4. Logs progress to ~/devsetup_YYYYMMDD_HHMMSS.log.
5. Rolls back on failure (if packages were installed).

## Customization
Edit `~/.config/devsetup/config.sh` to override defaults:
```bash
AUR_HELPER="paru"  # Default: yay
```

## Contributing
Found a bug or want to add a feature? Fork the repo, make changes, and submit a pull request! See the script’s inline comments for guidance.

## Troubleshooting
- Log file: Check `~/devsetup_*.log` for errors.
- Permission denied: Run with `sudo` if needed, but avoid running as root directly.
- Dialog fails: Ensure a TTY is available or use defaults in non-TTY mode.

## License 
MIT License - feel free to use, modify, and share!

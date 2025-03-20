#!/bin/bash
set -e  # Exit on any command failure

# --- Configuration ---
PACKAGE_MANAGER=""
DRY_RUN=false
VERBOSE=false
LOG_FILE="$HOME/devsetup_$(date +%Y%m%d_%H%M%S).log"
AUR_HELPER="yay"  # Default, can be overridden by config
CONFIG_DIR="$HOME/.config/devsetup"
CONFIG_FILE="$CONFIG_DIR/config.sh"
INSTALLED_PACKAGES=()
export DIALOGRC="/dev/null"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"  # Load user config (e.g., AUR_HELPER)

declare -A PKG_MAP=(
  ["git"]="git" ["curl"]="curl" ["wget"]="wget" ["htop"]="htop" ["neofetch"]="neofetch"
  ["vim"]="vim" ["neovim"]="neovim" ["vscode_apt"]="code" ["vscode_pacman"]="visual-studio-code-bin"
)

# --- Helper Functions ---

log() {
  local level="INFO"
  if [ "$1" = "ERROR" ] || [ "$1" = "WARNING" ]; then
    level="$1"
    shift
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] - $*" | tee -a "$LOG_FILE"
  [ "$level" = "ERROR" ] && echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] - $*" >&2
}

debug() { [ "$VERBOSE" = true ] && log "DEBUG" "$@"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

package_installed() {
  case "$PACKAGE_MANAGER" in
    apt-get) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "installed" ;;
    dnf) rpm -q "$1" &>/dev/null ;;
    pacman) pacman -Q "$1" &>/dev/null ;;
    zypper) zypper se --installed-only "$1" &>/dev/null ;;
    emerge) equery list "$1" &>/dev/null ;;
    *) return 1 ;;
  esac
}

check_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log "WARNING" "Running as root is not recommended."
    ask_confirmation "Continue anyway?" "N" || exit 1
  fi
}

ask_confirmation() {
  local prompt="$1"
  local default="${2:-N}"
  read -t 10 -p "$prompt (y/N, timeout 10s): " confirmation || {
    log "Timeout reached, defaulting to No."
    return 1
  }
  case "$confirmation" in
    [yY]*) return 0 ;;
    *) return 1 ;;
  esac
}

run_with_sudo() {
  if [ "$DRY_RUN" = true ]; then
    log "[Dry Run] Would run: $*"
    return 0
  fi
  debug "Running: $*"
  if [ "$(id -u)" -eq 0 ]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
  else
    sudo "$@" 2>&1 | tee -a "$LOG_FILE"
  fi
  return ${PIPESTATUS[0]}
}

install_package() {
  local pkg_key="$1"
  local force="${2:-false}"
  local pkg="${PKG_MAP["${pkg_key}_${PACKAGE_MANAGER}"]:-${PKG_MAP[$pkg_key]:-$pkg_key}}"
  if package_installed "$pkg" && [ "$force" = false ]; then
    log "$pkg is already installed."
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    log "[Dry Run] Would install $pkg"
    return 0
  fi
  debug "Mapped $pkg_key to $pkg for $PACKAGE_MANAGER"
  log "Checking dependencies before installing $pkg..."
  log "Installing $pkg..."
  case "$PACKAGE_MANAGER" in
    apt-get) run_with_sudo apt-get install -y "$pkg" || return 1 ;;
    dnf) run_with_sudo dnf install -y "$pkg" || return 1 ;;
    pacman)
      if echo "$pkg" | grep -qE "bin$"; then
        ensure_aur_helper
        "$AUR_HELPER" -S --needed --noconfirm "$pkg" || return 1
      else
        run_with_sudo pacman -S --needed --noconfirm "$pkg" || return 1
      fi
      ;;
    zypper) run_with_sudo zypper install -y "$pkg" || return 1 ;;
    emerge) run_with_sudo emerge --ask n "$pkg" || return 1 ;;
  esac
  INSTALLED_PACKAGES+=("$pkg")
  log "Successfully installed $pkg."
}

ensure_aur_helper() {
  local helpers=("$AUR_HELPER" "paru")
  for helper in "${helpers[@]}"; do
    if ! command_exists "$helper"; then
      log "Installing AUR helper ($helper)..."
      if ! pacman -Q base-devel >/dev/null 2>&1; then
        run_with_sudo pacman -S --needed --noconfirm base-devel
      fi
      run_with_sudo pacman -S --needed --noconfirm git
      local tmp_dir=$(mktemp -d)
      git clone "https://aur.archlinux.org/$helper.git" "$tmp_dir" && cd "$tmp_dir" && makepkg -si --noconfirm
      rm -rf "$tmp_dir"
      if command_exists "$helper"; then
        AUR_HELPER="$helper"
        log "Successfully installed $AUR_HELPER."
        return 0
      fi
    else
      AUR_HELPER="$helper"
      return 0
    fi
  done
  log "ERROR" "Failed to install any AUR helper (tried: ${helpers[*]})."
  exit 1
}

# --- Distribution Detection ---
detect_distribution() {
  if [ -e /etc/os-release ]; then
    . /etc/os-release
    debug "Loaded /etc/os-release: ID=$ID, PRETTY_NAME=$PRETTY_NAME"
    case "$ID" in
      ubuntu|debian|linuxmint|pop) PACKAGE_MANAGER="apt-get" ;;
      fedora|centos|rhel|rocky|alma) PACKAGE_MANAGER="dnf" ;;
      arch|manjaro|endeavouros) PACKAGE_MANAGER="pacman" ;;
      opensuse*) PACKAGE_MANAGER="zypper" ;;
      gentoo) PACKAGE_MANAGER="emerge" ;;
      *) log "ERROR" "Unsupported distribution: $ID"; exit 1 ;;
    esac
    log "Detected $PRETTY_NAME with $PACKAGE_MANAGER"
  else
    log "ERROR" "/etc/os-release not found."
    exit 1
  fi
}

# --- Rollback ---
rollback() {
  log "Rolling back changes..."
  if [ ${#INSTALLED_PACKAGES[@]} -eq 0 ]; then
    log "Nothing to roll back."
    return
  fi
  log "Removing installed packages: ${INSTALLED_PACKAGES[*]}"
  case "$PACKAGE_MANAGER" in
    apt-get) run_with_sudo apt-get remove -y "${INSTALLED_PACKAGES[@]}" ;;
    dnf) run_with_sudo dnf remove -y "${INSTALLED_PACKAGES[@]}" ;;
    pacman) run_with_sudo pacman -Rns --noconfirm "${INSTALLED_PACKAGES[@]}" ;;
    zypper) run_with_sudo zypper remove -y "${INSTALLED_PACKAGES[@]}" ;;
    emerge)
      for pkg in "${INSTALLED_PACKAGES[@]}"; do
        run_with_sudo emerge --unmerge "$pkg"
      done
      ;;
  esac
}

# --- Installation Functions ---
install_essentials() {
  log "--- Installing Essential Tools ---"
  local choices
  choices=$(dialog --checklist "Select essential tools:" 15 50 5 \
    "git" "Version control" on \
    "curl" "Data transfer tool" on \
    "wget" "Downloader" on \
    "htop" "Process viewer" off \
    "neofetch" "System info" off \
    3>&1 1>&2 2>&3)
  for pkg in $choices; do
    install_package "$pkg"
    SELECTED_ESSENTIALS+=("$pkg")
  done
}

install_code_editors() {
  log "--- Installing Code Editors ---"
  local choices
  choices=$(dialog --checklist "Select code editors:" 15 50 3 \
    "vim" "Text editor" off \
    "neovim" "Advanced text editor" off \
    "vscode_${PACKAGE_MANAGER}" "VS Code" on \
    3>&1 1>&2 2>&3)
  for editor in $choices; do
    install_package "$editor"
    SELECTED_EDITORS+=("$editor")
  done
}

select_categories() {
  if ! command_exists dialog; then
    log "ERROR" "Dialog is required but missing. Falling back to default installation."
    install_defaults
    exit 1
  fi
  dialog --menu "Select installation categories:" 15 50 5 \
    1 "Essential Tools" \
    2 "Code Editors" \
    8 "All" \
    9 "Done" 2>&1 >/dev/tty | while read choice; do
      case $choice in
        1) install_essentials ;;
        2) install_code_editors ;;
        8) install_essentials; install_code_editors ;;
        9) break ;;
      esac
    done
}

install_defaults() {
  log "No TTY detected (e.g., CI/CD or SSH). Installing default tools: git, curl, VS Code..."
  install_package "git"
  install_package "curl"
  install_package "vscode_${PACKAGE_MANAGER}"
  SELECTED_ESSENTIALS=("git" "curl")
  SELECTED_EDITORS=("vscode_${PACKAGE_MANAGER}")
}

# --- Main Script ---
while getopts "ndvh" opt; do
  case $opt in
    n) DRY_RUN=true; log "Dry run mode enabled." ;;
    d) DEV_MODE=true; log "Developer mode enabled." ;;
    v) VERBOSE=true; log "Verbose mode enabled." ;;
    h)
      echo "Usage: $0 [-n] [-d] [-v] [-h]"
      echo "  -n  Dry run: Simulate without changes"
      echo "  -d  Developer mode: Extra tools"
      echo "  -v  Verbose: Detailed output"
      echo "  -h  Help: Show this message"
      exit 0
      ;;
  esac
done

check_root
detect_distribution
if ! command_exists dialog; then
  log "Installing dialog for menu interface..."
  install_package "dialog"
fi
if [ -t 0 ]; then
  select_categories
else
  install_defaults
fi
log "Installation completed successfully!"

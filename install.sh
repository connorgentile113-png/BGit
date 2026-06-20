#!/usr/bin/env bash
#
# BGit — Better Git installer
# Installs the `bgit` command to your PATH.
#
set -uo pipefail

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/connorgentile113-png/BGit/main"
RAW_SCRIPT="$REPO_URL/bgit"

print_info()    { echo -e "${BLUE}ℹ️${NC}  $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error()   { echo -e "${RED}❌${NC} $1" >&2; }
print_warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
print_step()    { echo -e "  ${CYAN}→${NC} $1"; }
print_header()  { echo -e "\n${BOLD}${PURPLE}🚀 $1${NC}\n"; }

print_header "BGit — Better Git Installer"

# ─── Check for dependencies ─────────────────────────────────────────────────
print_step "Checking dependencies..."

if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    print_error "Neither curl nor wget is installed."
    print_info  "Please install curl or wget and try again."
    exit 1
fi

if ! command -v git &>/dev/null; then
    print_warn "Git is not installed. BGit requires git to function."
    print_info "You can still install BGit, but install git before using it."
fi

if ! command -v bash &>/dev/null; then
    print_error "Bash is required but not found."
    exit 1
fi

print_success "Dependencies OK."

# ─── Determine install location ─────────────────────────────────────────────
INSTALL_DIR=""
CANDIDATE_DIRS=(
    "$HOME/.local/bin"
    "$HOME/bin"
    "/usr/local/bin"
)

print_step "Finding a suitable install directory..."

for dir in "${CANDIDATE_DIRS[@]}"; do
    if [[ -d "$dir" ]] && [[ -w "$dir" ]]; then
        INSTALL_DIR="$dir"
        break
    fi
done

# If none exist and are writable, try to create ~/.local/bin
if [[ -z "$INSTALL_DIR" ]]; then
    if mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        INSTALL_DIR="$HOME/.local/bin"
    fi
fi

# Last resort: try /usr/local/bin with sudo
if [[ -z "$INSTALL_DIR" ]]; then
    if [[ -w "/usr/local/bin" ]]; then
        INSTALL_DIR="/usr/local/bin"
    else
        print_error "Could not find a writable directory in your PATH."
        print_info  "Try creating ~/.local/bin and adding it to your PATH:"
        print_info  "  mkdir -p ~/.local/bin && export PATH=\"\$HOME/.local/bin:\$PATH\""
        exit 1
    fi
fi

print_success "Install directory: ${BOLD}${INSTALL_DIR}${NC}"

# ─── Check if bgit already installed ────────────────────────────────────────
INSTALL_PATH="${INSTALL_DIR}/bgit"

if [[ -f "$INSTALL_PATH" ]]; then
    print_info "An existing installation of bgit was found at ${INSTALL_PATH}"
    read -rp "$(echo -e ${BLUE}ℹ️${NC}  Overwrite? [Y/n])" choice
    choice=${choice:-Y}
    if [[ "${choice,,}" != "y" ]] && [[ "${choice,,}" != "yes" ]]; then
        print_info "Installation cancelled."
        exit 0
    fi
fi

# ─── Download bgit ──────────────────────────────────────────────────────────
print_step "Downloading bgit..."

TMP_FILE=$(mktemp)

if command -v curl &>/dev/null; then
    if ! curl -fsSL "$RAW_SCRIPT" -o "$TMP_FILE"; then
        print_error "Failed to download bgit from GitHub."
        print_info  "Check your internet connection or the repository URL."
        print_info  "URL: $RAW_SCRIPT"
        rm -f "$TMP_FILE"
        exit 1
    fi
else
    if ! wget -qO "$TMP_FILE" "$RAW_SCRIPT"; then
        print_error "Failed to download bgit from GitHub."
        rm -f "$TMP_FILE"
        exit 1
    fi
fi

# CRITICAL FIX: Remove Windows CRLF line endings if present
sed -i 's/\r$//' "$TMP_FILE"

# Verify the downloaded file looks like a bash script
if ! head -1 "$TMP_FILE" | grep -q "bash"; then
    print_error "Downloaded file does not appear to be a valid script."
    print_info  "This might indicate the repository doesn't exist yet or"
    print_info  "the main branch isn't published. Make sure you've pushed"
    print_info  "the bgit script to the 'main' branch of:"
    print_info  "  https://github.com/connorgentile113-png/BGit"
    rm -f "$TMP_FILE"
    exit 1
fi

print_success "Downloaded successfully."

# ─── Install ────────────────────────────────────────────────────────────────
print_step "Installing to ${INSTALL_PATH}..."

# If we need sudo (e.g., /usr/local/bin)
if [[ ! -w "$INSTALL_DIR" ]]; then
    sudo cp "$TMP_FILE" "$INSTALL_PATH" 2>/dev/null || cp "$TMP_FILE" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH" 2>/dev/null || chmod +x "$INSTALL_PATH"
else
    cp "$TMP_FILE" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
fi

rm -f "$TMP_FILE"

if [[ ! -f "$INSTALL_PATH" ]]; then
    print_error "Installation failed — file not found at ${INSTALL_PATH}"
    exit 1
fi

print_success "Installed to ${INSTALL_PATH}"

# ─── Verify it's in PATH ────────────────────────────────────────────────────
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    print_warn "${INSTALL_DIR} is not in your PATH."
    echo
    print_info "Add this line to your shell config (~/.bashrc, ~/.zshrc, etc.):"
    echo
    echo -e "    ${BOLD}export PATH=\"${INSTALL_DIR}:\$PATH\"${NC}"
    echo

    # Try to auto-add it
    SHELL_RC=""
    if [[ -n "${BASH_VERSION:-}" ]] && [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]] && [[ -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [[ -n "$SHELL_RC" ]]; then
        read -rp "$(echo -e ${BLUE}ℹ️${NC}  Add to ${SHELL_RC} automatically? [Y/n])" add_choice
        add_choice=${add_choice:-Y}
        if [[ "${add_choice,,}" == "y" ]] || [[ "${add_choice,,}" == "yes" ]]; then
            echo "" >> "$SHELL_RC"
            echo "# Added by BGit installer" >> "$SHELL_RC"
            echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "$SHELL_RC"
            print_success "Added to ${SHELL_RC}"
            print_info "Run ${BOLD}source ${SHELL_RC}${NC} or restart your terminal."
        fi
    fi
fi

# ─── Done ───────────────────────────────────────────────────────────────────
echo
print_success "BGit is installed! 🎉"
echo
echo -e "  ${BOLD}Quick start:${NC}"
echo -e "    ${DIM}bgit help${NC}              — see all commands"
echo -e "    ${DIM}bgit init${NC}              — start a new repo"
echo -e "    ${DIM}bgit status${NC}            — check repo state"
echo -e "    ${DIM}bgit add . && bgit commit${NC}  — stage & commit"
echo -e "    ${DIM}bgit push${NC}              — push to remote"
echo -e "    ${DIM}bgit resolve${NC}           — auto-fix conflicts"
echo
echo -e "  ${DIM}https://github.com/connorgentile113-png/BGit${NC}"
echo

#!/usr/bin/env bash
# macOS All-in-One Developer Setup Script
# by Craig Williamson
# Configures macOS preferences, Homebrew, Git, SSH, VS Code, and clones repos.

set -euo pipefail

echo "=== 🚀 Starting macOS Developer Setup ==="

########################################
# 1. macOS Preferences — Trackpad + Gestures
########################################
echo "Configuring trackpad and disabling Mission Control gestures..."

defaults write NSGlobalDomain ContextMenuGesture -int 1
defaults write -g com.apple.trackpad.enableSecondaryClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2

defaults write com.apple.dock showMissionControlGestureEnabled -bool false
defaults write com.apple.dock showAppExposeGestureEnabled -bool false
defaults write com.apple.dock showDesktopGestureEnabled -bool false

killall cfprefsd 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "✅ Trackpad and gestures configured."

########################################
# 2. Homebrew
########################################
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✅ Homebrew already installed."
fi

# Activate Brew
if [[ -d "/opt/homebrew/bin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d "/usr/local/bin" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

brew update && brew upgrade

########################################
# 3. Developer Tools
########################################
echo "Installing developer tools..."
brew install git python node gh jq wget neovim || true

if ! command -v python &>/dev/null && command -v python3 &>/dev/null; then
  sudo ln -sf "$(which python3)" /usr/local/bin/python || true
fi

echo "✅ Installed Git, Python, Node.js, GitHub CLI, and utilities."

########################################
# 4. GUI Applications
########################################
echo "Installing desktop applications..."
brew install --cask visual-studio-code spotify --no-quarantine || true
echo "✅ Installed VS Code and Spotify."

########################################
# 5. Git Configuration & SSH Setup
########################################
echo "Setting up Git..."

if ! git config --global user.name &>/dev/null; then
  read -p "Enter your Git name: " git_name
  git config --global user.name "$git_name"
else
  git_name=$(git config --global user.name)
fi

if ! git config --global user.email &>/dev/null; then
  read -p "Enter your Git email: " git_email
  git config --global user.email "$git_email"
else
  git_email=$(git config --global user.email)
fi

git config --global core.editor "code --wait"
git config --global init.defaultBranch main
echo "✅ Git configured for $git_name <$git_email>"

# SSH setup
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
  echo "Generating new SSH key..."
  mkdir -p ~/.ssh
  ssh-keygen -t ed25519 -C "$git_email" -f "$SSH_KEY" -N ""
  eval "$(ssh-agent -s)"
  ssh-add --apple-use-keychain "$SSH_KEY"
  echo "✅ SSH key generated."
else
  echo "✅ SSH key already exists."
fi

echo
echo "🔑 Your public SSH key (add this to GitHub → Settings → SSH and GPG keys):"
cat "${SSH_KEY}.pub"
echo
read -p "Once added, press Enter to continue..."

########################################
# 6. Clone GitHub Repositories
########################################
read -p "Enter your GitHub username (or leave blank to skip): " gh_user
DEV_DIR="$HOME/development"
mkdir -p "$DEV_DIR"

if [[ -n "$gh_user" ]]; then
  gh auth login --hostname github.com --git-protocol ssh --web
  cd "$DEV_DIR"
  echo "Cloning or updating repos..."
  gh repo list "$gh_user" --limit 100 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
    repo_name=$(basename "$repo")
    if [[ -d "$repo_name/.git" ]]; then
      echo "🔄 Updating $repo_name..."
      (cd "$repo_name" && git pull --rebase) || true
    else
      echo "⬇️  Cloning $repo_name..."
      git clone "git@github.com:${repo}.git" || true
    fi
  done
  echo "✅ Repositories ready in $DEV_DIR"
else
  echo "⏭️  Skipped cloning GitHub repos."
fi

########################################
# 7. VS Code Setup (Resilient Installer)
########################################
echo "=== Setting up Visual Studio Code ==="

# Check VS Code CLI
if ! command -v code &>/dev/null; then
  echo "⚠️  VS Code CLI not found."
  echo "👉 Open VS Code, then run: 'Shell Command: Install code command in PATH'"
  echo "Press Enter when done."
  read -r
fi

# If still not found, skip VS Code
if ! command -v code &>/dev/null; then
  echo "❌ Skipping VS Code setup (CLI missing)."
else
  echo "✅ VS Code CLI found. Installing extensions..."

  EXTENSIONS=(
    vscodevim.vim
    esbenp.prettier-vscode
    ms-vscode-remote.remote-ssh
    pkief.material-icon-theme
    dbaeumer.vscode-eslint
    catppuccin.catppuccin-vsc
    ms-python.python
    ms-python.vscode-pylance
  )

  for ext in "${EXTENSIONS[@]}"; do
    echo "Installing $ext..."
    if ! code --install-extension "$ext" --force >/dev/null 2>&1; then
      echo "⚠️  CLI crashed while installing $ext – opening fallback link..."
      open "vscode://extensions/install?itemName=$ext"
    fi
  done

  # Apply settings and keybindings
  VSCODE_DIR="$HOME/Library/Application Support/Code/User"
  mkdir -p "$VSCODE_DIR"

  cat > "$VSCODE_DIR/settings.json" <<'JSON'
{
  "workbench.colorTheme": "Catppuccin Mocha",
  "workbench.iconTheme": "material-icon-theme",
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.formatOnSave": true,
  "editor.formatOnPaste": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.minimap.enabled": false,
  "vim.useSystemClipboard": true,
  "vim.leader": "<space>",
  "vim.insertModeKeyBindings": [
    { "before": ["j", "k"], "after": ["<Esc>"] }
  ],
  "vim.normalModeKeyBindingsNonRecursive": [
    { "before": ["<leader>", "w"], "commands": ["workbench.action.files.save"] },
    { "before": ["<leader>", "t"], "commands": ["workbench.action.terminal.toggleTerminal"] },
    { "before": ["<leader>", "e"], "commands": ["workbench.view.explorer"] },
    { "before": ["<leader>", "f"], "commands": ["editor.action.formatDocument"] }
  ],
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.cursorBlinking": true,
  "files.exclude": {
    "**/__pycache__": true,
    "**/.DS_Store": true,
    "**/node_modules": true
  }
}
JSON

  cat > "$VSCODE_DIR/keybindings.json" <<'JSON'
[
  {
    "key": "j k",
    "command": "extension.vim_escape",
    "when": "editorTextFocus && vim.active && vim.mode == 'Insert'"
  },
  {
    "key": "space t",
    "command": "workbench.action.terminal.toggleTerminal",
    "when": "editorTextFocus && vim.active && vim.mode == 'Normal'"
  },
  {
    "key": "space f",
    "command": "editor.action.formatDocument",
    "when": "editorTextFocus && vim.active && vim.mode == 'Normal'"
  }
]
JSON

  echo "✅ VS Code fully configured."
fi

########################################
# 8. Cleanup
########################################
brew cleanup || true
echo
echo "🎉 All setup complete!"
echo "Repos are in ~/development"
echo "VS Code is ready with Vim, Prettier, ESLint, Catppuccin, and keybindings."

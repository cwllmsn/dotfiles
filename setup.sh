#!/bin/bash
# macOS Bootstrap Script (dotfiles)
# Safe to re-run. Configures trackpad, installs dev tools, and syncs repos.

set -euo pipefail

echo "=== Starting macOS setup ==="

########################################
# 1. macOS Preferences — Trackpad + Gestures
########################################
echo "Configuring trackpad for bottom-right right-click and disabling Mission Control gestures..."

# Enable secondary click globally
defaults write NSGlobalDomain ContextMenuGesture -int 1
defaults write -g com.apple.trackpad.enableSecondaryClick -bool true

# Built-in trackpad
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2

# External (Bluetooth) trackpad
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2

# Disable “Mission Control / Show Desktop” gestures
defaults write com.apple.dock showMissionControlGestureEnabled -bool false
defaults write com.apple.dock showAppExposeGestureEnabled -bool false
defaults write com.apple.dock showDesktopGestureEnabled -bool false

# Restart preference daemons
killall cfprefsd 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "✅ Trackpad and gestures configured. (Reboot or log out/in to fully apply.)"

########################################
# 2. Homebrew
########################################
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✅ Homebrew already installed."
fi

# Activate Homebrew in current shell
if [[ -d "/opt/homebrew/bin" ]]; then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d "/usr/local/bin" ]]; then
  echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/usr/local/bin/brew shellenv)"
fi

brew update && brew upgrade

########################################
# 3. Developer Tools
########################################
echo "Installing development tools..."

brew install git || true
brew install python || true
brew install node || true
brew install gh || true  # GitHub CLI

# Ensure "python" command exists
if ! command -v python &>/dev/null && command -v python3 &>/dev/null; then
  sudo ln -sf "$(which python3)" /usr/local/bin/python || true
fi

echo "✅ Installed Git, Python, Node.js, and GitHub CLI."

########################################
# 4. GUI Applications via Casks
########################################
echo "Installing desktop applications..."

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

install_cask_if_missing() {
  local app_name=$1
  local app_path="/Applications/$2.app"

  if [ -d "$app_path" ]; then
    echo "✅ $2 already present in /Applications."
  elif brew list --cask "$app_name" &>/dev/null; then
    echo "✅ $2 already installed via Homebrew Cask."
  else
    echo "⬇️  Installing $2..."
    brew install --cask "$app_name" --no-quarantine || echo "⚠️  Skipped $2."
  fi
}

install_cask_if_missing visual-studio-code "Visual Studio Code"
install_cask_if_missing chatgpt "ChatGPT"
install_cask_if_missing spotify "Spotify"

echo "✅ Desktop applications ready."

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
echo "✅ Git configured for $git_name <$git_email>"

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
echo
cat "${SSH_KEY}.pub"
echo
read -p "Once added, press Enter to continue..."

########################################
# 6. Clone GitHub Repositories
########################################
read -p "Enter your GitHub username (or leave blank to skip cloning): " gh_user

if [[ -n "$gh_user" ]]; then
  echo "Authenticating GitHub CLI..."
  gh auth login --hostname github.com --git-protocol ssh --web

  DEV_DIR="$HOME/development"
  mkdir -p "$DEV_DIR"
  cd "$DEV_DIR"

  echo "Cloning or updating repositories in $DEV_DIR..."
  gh repo list "$gh_user" --limit 100 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
    repo_name=$(basename "$repo")
    if [[ -d "$repo_name/.git" ]]; then
      echo "🔄 Updating $repo_name..."
      (cd "$repo_name" && git pull --rebase) || echo "⚠️  Could not update $repo_name"
    else
      echo "⬇️  Cloning $repo_name..."
      git clone "git@github.com:${repo}.git" || echo "⚠️  Skipped $repo_name"
    fi
  done
  echo "✅ Repositories ready in $DEV_DIR"
else
  echo "⏭️  Skipped cloning GitHub repos."
fi

########################################
# 7. Cleanup
########################################
brew cleanup || true
echo
echo "🎉 Setup complete!"
echo "Your repositories are in ~/development"
echo "You may need to run 'source ~/.zprofile' or restart Terminal."

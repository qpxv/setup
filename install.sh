#!/usr/bin/env bash
# sets up a mac from zero: brew + tools, every github repo into ~/Projects,
# claude config into ~/.claude, dotfiles linked into ~.
# safe to rerun: skips whatever is already there, so it also pulls in new repos.
set -euo pipefail

GITHUB_USER="qpxv"
PROJECTS_DIR="$HOME/Projects"
SETUP_DIR="$PROJECTS_DIR/setup"
CLAUDE_REPO="claude-config"
CLAUDE_DIR="$HOME/.claude"
REPO_LIMIT=1000
BREW_PREFIX="/opt/homebrew"
LINKED_FILES=(zshrc zprofile gitconfig)
THEME_SYNC="terminal-theme-sync"
THEME_SYNC_LABEL="com.benwinzer.$THEME_SYNC"
THEME_SYNC_BIN="$HOME/.local/bin/$THEME_SYNC"
THEME_SYNC_PLIST="$HOME/Library/LaunchAgents/$THEME_SYNC_LABEL.plist"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

install_brew() {
  if [ ! -x "$BREW_PREFIX/bin/brew" ]; then
    say "installing homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
}

login_github() {
  command -v gh >/dev/null || brew install gh
  if ! gh auth status >/dev/null 2>&1; then
    say "logging into github"
    gh auth login --web --git-protocol https
  fi
}

clone_projects() {
  say "cloning repos into $PROJECTS_DIR"
  mkdir -p "$PROJECTS_DIR"
  repos="$(gh repo list "$GITHUB_USER" --limit "$REPO_LIMIT" --source --no-archived --json name --jq '.[].name')"
  for repo in $repos; do
    [ "$repo" = "$CLAUDE_REPO" ] && continue
    if [ -d "$PROJECTS_DIR/$repo" ]; then
      echo "  ok      $repo"
    else
      echo "  clone   $repo"
      gh repo clone "$GITHUB_USER/$repo" "$PROJECTS_DIR/$repo" -- --quiet
    fi
  done
}

clone_claude_config() {
  [ -d "$CLAUDE_DIR/.git" ] && return
  say "cloning claude config into $CLAUDE_DIR"
  # claude creates ~/.claude on first launch, keep that around instead of overwriting it
  if [ -e "$CLAUDE_DIR" ]; then
    mv "$CLAUDE_DIR" "$CLAUDE_DIR.backup-$(date +%Y%m%d%H%M%S)"
  fi
  gh repo clone "$GITHUB_USER/$CLAUDE_REPO" "$CLAUDE_DIR" -- --quiet
}

install_tools() {
  say "installing brew packages"
  brew bundle --no-upgrade --file "$SETUP_DIR/Brewfile"
  say "installing global npm packages"
  while read -r pkg; do
    [ -z "$pkg" ] && continue
    npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 || npm install -g "$pkg"
  done <"$SETUP_DIR/npm-globals.txt"
}

link_dotfiles() {
  say "linking dotfiles"
  for name in "${LINKED_FILES[@]}"; do
    target="$HOME/.$name"
    file="$SETUP_DIR/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$file" ]; then
      echo "  ok      ~/.$name"
      continue
    fi
    if [ -L "$target" ]; then
      # an old link (e.g. to a renamed folder) holds nothing worth keeping
      rm "$target"
    elif [ -e "$target" ]; then
      mv "$target" "$target.backup-$(date +%Y%m%d%H%M%S)"
    fi
    ln -s "$file" "$target"
    echo "  linked  ~/.$name"
  done
}

# terminal.app follows the system light/dark mode, see terminal-theme-sync/main.swift
install_theme_sync() {
  say "setting up $THEME_SYNC"
  local src="$SETUP_DIR/$THEME_SYNC/main.swift"
  if [ ! -x "$THEME_SYNC_BIN" ] || [ "$src" -nt "$THEME_SYNC_BIN" ]; then
    mkdir -p "$(dirname "$THEME_SYNC_BIN")"
    swiftc -O "$src" -o "$THEME_SYNC_BIN"
    # restart so a rebuilt binary actually runs
    launchctl bootout "gui/$UID/$THEME_SYNC_LABEL" 2>/dev/null || true
    echo "  built   $THEME_SYNC_BIN"
  fi
  if [ ! -f "$THEME_SYNC_PLIST" ]; then
    mkdir -p "$(dirname "$THEME_SYNC_PLIST")"
    cat >"$THEME_SYNC_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$THEME_SYNC_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$THEME_SYNC_BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardErrorPath</key>
    <string>/tmp/$THEME_SYNC.log</string>
</dict>
</plist>
EOF
  fi
  if launchctl print "gui/$UID/$THEME_SYNC_LABEL" >/dev/null 2>&1; then
    echo "  ok      running"
  else
    launchctl bootstrap "gui/$UID" "$THEME_SYNC_PLIST"
    echo "  started (macOS asks once to allow controlling Terminal)"
  fi
}

install_brew
login_github
clone_projects
clone_claude_config
install_tools
link_dotfiles
install_theme_sync
say "done. open a new terminal tab to load the new zshrc"

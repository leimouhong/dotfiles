#!/usr/bin/env zsh
# dotfiles/mac/install.sh (Mac 一鍵配置)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

########################################
# Homebrew
########################################
if ! command -v brew >/dev/null 2>&1; then
  echo "==> 安裝 Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # 依晶片載入 brew 路徑
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"      # Intel
  fi
else
  echo "==> Homebrew 已安裝，更新中"
  brew update -q
fi

########################################
# 套件安裝
########################################
echo "==> 安裝套件"
brew install \
  zinit \
  eza \
  fzf \
  fd \
  zoxide \
  starship \
  fastfetch \
  ripgrep \
  neovim \
  lazygit \
  zellij

########################################
# NVM
########################################
if [[ ! -d "$HOME/.nvm" ]]; then
  echo "==> 安裝 NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
  echo "==> NVM 已安裝，跳過"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts

########################################
# 套用 zellij 設定
########################################
echo "==> 套用 zellij 設定"
mkdir -p "$HOME/.config/zellij"
if [[ -f "$HOME/.config/zellij/config.kdl" ]]; then
  cp "$HOME/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 zellij 設定至 ~/.config/zellij/config.kdl.backup.*"
fi
if [[ -f "$SCRIPT_DIR/../zellij/config.kdl" ]]; then
  cp "$SCRIPT_DIR/../zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
else
  curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/config.kdl -o "$HOME/.config/zellij/config.kdl"
fi

########################################
# 套用 .zshrc
########################################
echo "==> 套用 .zshrc"
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 .zshrc 至 ~/.zshrc.backup.*"
fi
if [[ -f "$SCRIPT_DIR/.zshrc" ]]; then
  cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
else
  curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/.zshrc -o "$HOME/.zshrc"
fi

echo ""
echo "✅ 完成！執行 source ~/.zshrc 生效"

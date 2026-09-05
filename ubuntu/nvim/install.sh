#!/usr/bin/env bash
# 將個人 LazyVim 設定部署到 Ubuntu；Neovim 與系統依賴由 ubuntu/install.sh 負責。
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "此腳本供 Ubuntu 部署使用，請在 Ubuntu 執行；macOS 的 Neovim 設定由移轉輔助程式搬移。" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="$CONFIG_HOME/nvim"
SOURCE_DIR="$SCRIPT_DIR/config"

mkdir -p "$CONFIG_HOME"
WORK_DIR="$(mktemp -d "$CONFIG_HOME/.nvim-install.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# 支援直接執行本地腳本，也支援 bash <(curl ...)。
if [[ ! -f "$SOURCE_DIR/init.lua" ]]; then
  echo "==> 從 dotfiles 下載個人 LazyVim 設定"
  git clone -q --depth 1 https://github.com/leimouhong/dotfiles.git "$WORK_DIR/dotfiles"
  SOURCE_DIR="$WORK_DIR/dotfiles/ubuntu/nvim/config"
fi

if [[ ! -f "$SOURCE_DIR/init.lua" || ! -f "$SOURCE_DIR/lua/config/lazy.lua" || ! -f "$SOURCE_DIR/lazy-lock.json" ]]; then
  echo "找不到完整的 LazyVim 設定：$SOURCE_DIR" >&2
  exit 1
fi

# 先完成複製，再移動既有設定，避免下載或複製失敗影響原有環境。
mkdir "$WORK_DIR/config"
cp -R "$SOURCE_DIR/." "$WORK_DIR/config/"

BACKUP_DIR=""
if [[ -e "$CONFIG_DIR" || -L "$CONFIG_DIR" ]]; then
  BACKUP_DIR="$(mktemp -d "$CONFIG_HOME/nvim.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")"
  mv "$CONFIG_DIR" "$BACKUP_DIR/nvim"
  echo "   已備份原有設定至 $BACKUP_DIR/nvim"
fi

if ! mv "$WORK_DIR/config" "$CONFIG_DIR"; then
  if [[ -n "$BACKUP_DIR" ]]; then
    mv "$BACKUP_DIR/nvim" "$CONFIG_DIR"
    rmdir "$BACKUP_DIR"
  fi
  echo "套用 LazyVim 設定失敗。" >&2
  exit 1
fi

echo "✅ 已套用個人 LazyVim 設定至 $CONFIG_DIR"
echo "   開啟 nvim，等待外掛安裝完成，再執行 :Lazy restore 與 :LazyHealth"

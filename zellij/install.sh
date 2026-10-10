#!/usr/bin/env bash
# dotfiles/zellij/install.sh (zellij 單獨安裝 + 套用本資料夾的 config.kdl)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_URL="https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/config.kdl"
CONFIG_DIR="${DOTFILES_ZELLIJ_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zellij}"
# Linux 預設使用個人位置；只有明確指定 DOTFILES_ZELLIJ_CONFIG_DIR 才另選目錄。
if [[ "$(uname -s)" == Linux && -z ${DOTFILES_ZELLIJ_CONFIG_DIR:-} ]]; then
  CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tom/zellij"
fi
WORK_DIR=$(mktemp -d)
CONFIG_STAGE=""
trap 'rm -rf "$WORK_DIR"; if [[ -n "$CONFIG_STAGE" ]]; then rm -f "$CONFIG_STAGE"; fi' EXIT

# 先下載完整設定；網路失敗時保留既有設定。
if [[ -f "$SCRIPT_DIR/config.kdl" ]]; then
  cp "$SCRIPT_DIR/config.kdl" "$WORK_DIR/config.kdl"
else
  curl -fsSL --retry 3 "$CONFIG_URL" -o "$WORK_DIR/config.kdl"
fi
if [[ "$CONFIG_DIR" == "${XDG_CONFIG_HOME:-$HOME/.config}/tom/zellij" && -x /usr/local/bin/tom ]]; then
  printf '\n// Ubuntu 個人環境的新窗格\ndefault_shell "/usr/local/bin/tom"\n' >> "$WORK_DIR/config.kdl"
fi

# ZELLIJ_REINSTALL=1 可強制重裝已存在的 zellij
ZELLIJ_REINSTALL="${ZELLIJ_REINSTALL:-0}"

# 取得最新版本號（帶 v 前綴）
_latest_v() {
  local tag
  tag=$(curl -fsSL --retry 3 "https://api.github.com/repos/$1/releases/latest" \
    | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p') || return 1
  if [[ ! "$tag" =~ ^v[0-9]+(\.[0-9]+)+$ ]]; then
    echo "無法取得有效的 zellij 版本。" >&2
    return 1
  fi
  printf '%s\n' "$tag"
}

########################################
# 安裝 zellij
########################################
install_zellij_macos() {
  if command -v brew >/dev/null 2>&1; then
    echo "==> 透過 Homebrew 安裝 zellij"
    brew install zellij
    return
  fi

  echo "==> 未偵測到 Homebrew，改用 GitHub release 安裝 zellij"
  case "$(uname -m)" in
    arm64|aarch64) ZJ_ARCH="aarch64-apple-darwin" ;;
    x86_64)        ZJ_ARCH="x86_64-apple-darwin" ;;
    *) echo "不支援的架構：$(uname -m)"; exit 1 ;;
  esac
  install_zellij_release "$ZJ_ARCH"
}

install_zellij_linux() {
  echo "==> 透過 GitHub release 安裝 zellij"
  case "$(uname -m)" in
    x86_64)        ZJ_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) ZJ_ARCH="aarch64-unknown-linux-musl" ;;
    *) echo "不支援的架構：$(uname -m)"; exit 1 ;;
  esac
  install_zellij_release "$ZJ_ARCH"
}

install_zellij_release() {
  local arch="$1" tag
  tag=$(_latest_v zellij-org/zellij)
  echo "   版本：${tag}（${arch}）"
  curl -fsSL --retry 3 -o "$WORK_DIR/zellij.tar.gz" \
    "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-${arch}.tar.gz"
  tar -xzf "$WORK_DIR/zellij.tar.gz" -C "$WORK_DIR" zellij
  # 驗證架構與設定相容性後，再替換執行檔。
  "$WORK_DIR/zellij" --version
  "$WORK_DIR/zellij" --config "$WORK_DIR/config.kdl" setup --check
  if [[ $EUID -eq 0 ]]; then
    install -d -m 0755 /usr/local/bin
    install -m 0755 "$WORK_DIR/zellij" /usr/local/bin/zellij
  else
    sudo install -d -m 0755 /usr/local/bin
    sudo install -m 0755 "$WORK_DIR/zellij" /usr/local/bin/zellij
  fi
}

if command -v zellij >/dev/null 2>&1 && [[ "$ZELLIJ_REINSTALL" != "1" ]]; then
  echo "==> zellij 已安裝（$(zellij --version)），跳過安裝"
  echo "   要重裝請執行：ZELLIJ_REINSTALL=1 $0"
else
  case "$(uname -s)" in
    Darwin) install_zellij_macos ;;
    Linux)  install_zellij_linux ;;
    *) echo "不支援的作業系統：$(uname -s)"; exit 1 ;;
  esac
fi

########################################
# 套用 zellij 設定
########################################
echo "==> 套用 zellij 設定"
zellij --config "$WORK_DIR/config.kdl" setup --check
mkdir -p "$CONFIG_DIR"
if cmp -s "$WORK_DIR/config.kdl" "$CONFIG_DIR/config.kdl"; then
  echo "   zellij 設定相同，保留現有檔案。"
else
  # 在設定目錄先準備完整檔案，再備份及切換，避免覆寫符號連結的目標。
  CONFIG_STAGE=$(mktemp "$CONFIG_DIR/.config.kdl.XXXXXX")
  cp "$WORK_DIR/config.kdl" "$CONFIG_STAGE"
  if [[ -e "$CONFIG_DIR/config.kdl" || -L "$CONFIG_DIR/config.kdl" ]]; then
    BACKUP=$(mktemp -d "$CONFIG_DIR/backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
    cp -P "$CONFIG_DIR/config.kdl" "$BACKUP/config.kdl"
    echo "   已備份原有 zellij 設定至 $BACKUP/config.kdl"
  fi
  mv "$CONFIG_STAGE" "$CONFIG_DIR/config.kdl"
  echo "   已套用 zellij 設定。"
fi

echo ""
echo "✅ 完成！設定已安裝至 ${CONFIG_DIR}（autolock plugin 首次啟動會自動下載）"
if [[ "$CONFIG_DIR" == "${XDG_CONFIG_HOME:-$HOME/.config}/tom/zellij" ]]; then
  echo "   完整安裝後執行 tom，再執行 zellij。"
  printf '   也可單獨執行：zellij --config-dir %q\n' "$CONFIG_DIR"
else
  echo "   執行 zellij 啟動。"
fi

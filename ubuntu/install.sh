#!/usr/bin/env bash
# dotfiles/ubuntu/install.sh (Ubuntu 一鍵配置)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 偵測架構
DPKG_ARCH=$(dpkg --print-architecture)
case "$DPKG_ARCH" in
  amd64)
    NVIM_ARCH="x86_64"
    LG_ARCH="x86_64"
    RG_ARCH="x86_64-unknown-linux-musl"
    FD_ARCH="x86_64-unknown-linux-musl"
    ;;
  arm64)
    NVIM_ARCH="arm64"
    LG_ARCH="arm64"
    RG_ARCH="aarch64-unknown-linux-gnu"
    FD_ARCH="aarch64-unknown-linux-musl"
    ;;
  *) echo "不支援的架構：$DPKG_ARCH"; exit 1 ;;
esac

# 取得最新版本號（帶 v 前綴）
_latest_v() { curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/'; }
# 取得最新版本號（去除 v 前綴）
_latest()   { _latest_v "$1" | sed 's/^v//'; }

echo "==> 更新套件"
sudo apt update -qq

echo "==> 安裝基礎套件"
sudo apt install -y git curl unzip wget gpg ca-certificates build-essential gawk

echo "==> 安裝 ripgrep"
RG_VER=$(_latest BurntSushi/ripgrep)
curl -sLo /tmp/rg.tar.gz \
  "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VER}/ripgrep-${RG_VER}-${RG_ARCH}.tar.gz"
tar -xzf /tmp/rg.tar.gz -C /tmp "ripgrep-${RG_VER}-${RG_ARCH}/rg"
sudo install "/tmp/ripgrep-${RG_VER}-${RG_ARCH}/rg" /usr/local/bin/rg
rm -rf /tmp/rg.tar.gz "/tmp/ripgrep-${RG_VER}-${RG_ARCH}"

echo "==> 安裝 fd"
FD_VER=$(_latest sharkdp/fd)
curl -sLo /tmp/fd.tar.gz \
  "https://github.com/sharkdp/fd/releases/download/v${FD_VER}/fd-v${FD_VER}-${FD_ARCH}.tar.gz"
tar -xzf /tmp/fd.tar.gz -C /tmp "fd-v${FD_VER}-${FD_ARCH}/fd"
sudo install "/tmp/fd-v${FD_VER}-${FD_ARCH}/fd" /usr/local/bin/fd
rm -rf /tmp/fd.tar.gz "/tmp/fd-v${FD_VER}-${FD_ARCH}"

echo "==> 安裝 fzf"
rm -rf ~/.fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --bin
FZF_BIN=$(realpath ~/.fzf/bin/fzf)
[[ "$FZF_BIN" != "/usr/local/bin/fzf" ]] && sudo install "$FZF_BIN" /usr/local/bin/fzf
unset FZF_BIN

echo "==> 安裝 eza"
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
  | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
sudo apt update -qq && sudo apt install -y eza

echo "==> 安裝 zoxide"
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

echo "==> 安裝 ble.sh"
BLE_SRC=$(mktemp -d)
git clone -q --recursive https://github.com/akinomyoga/ble.sh.git "$BLE_SRC"
make -C "$BLE_SRC" install PREFIX=~/.local --quiet
rm -rf "$BLE_SRC"
unset BLE_SRC

echo "==> 從源碼安裝 keyd"
KEYD_SRC=$(mktemp -d)
KEYD_TAG=$(
  git ls-remote --tags --refs https://github.com/rvaiya/keyd.git 'v*' \
    | awk -F/ '{print $3}' \
    | grep -E '^v[0-9]+(\.[0-9]+)*$' \
    | sort -V \
    | tail -n1 \
    || true
)
if [[ -n "$KEYD_TAG" ]]; then
  git clone -q --depth 1 --branch "$KEYD_TAG" https://github.com/rvaiya/keyd.git "$KEYD_SRC"
else
  git clone -q --depth 1 https://github.com/rvaiya/keyd.git "$KEYD_SRC"
fi
make -C "$KEYD_SRC" --quiet
sudo make -C "$KEYD_SRC" install --quiet
rm -rf "$KEYD_SRC"
unset KEYD_SRC KEYD_TAG

echo "==> 套用 keyd 設定（Tab + hjkl 方向鍵）"
sudo mkdir -p /etc/keyd
if [[ -f /etc/keyd/default.conf ]]; then
  sudo cp /etc/keyd/default.conf "/etc/keyd/default.conf.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 keyd 設定至 /etc/keyd/default.conf.backup.*"
fi
if [[ -f "$SCRIPT_DIR/keyd/default.conf" ]]; then
  sudo install -m 0644 "$SCRIPT_DIR/keyd/default.conf" /etc/keyd/default.conf
else
  sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
[ids]
*

[main]
tab = overload(nav, tab)

[nav]
h = left
j = down
k = up
l = right
EOF
fi
sudo keyd check /etc/keyd/default.conf
sudo systemctl daemon-reload
sudo systemctl enable --now keyd
sudo keyd reload

echo "==> 安裝 Neovim（AppImage，$DPKG_ARCH）"
curl -sLo /tmp/nvim.appimage \
  "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.appimage"
chmod +x /tmp/nvim.appimage
sudo mv /tmp/nvim.appimage /usr/local/bin/nvim

echo "==> 安裝 lazygit"
LAZYGIT_VERSION=$(_latest jesseduffield/lazygit)
curl -sLo /tmp/lazygit.tar.gz \
  "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz"
tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit /usr/local/bin
rm /tmp/lazygit.tar.gz /tmp/lazygit

echo "==> 安裝 nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts

echo "==> 安裝 LazyVim"
if [[ -d "$HOME/.config/nvim" ]]; then
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 nvim 設定至 ~/.config/nvim.backup.*"
fi
git clone -q https://github.com/LazyVim/starter "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim/.git"

echo "==> 套用 .bashrc"
if [[ -f "$HOME/.bashrc" ]]; then
  cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
  echo "   已備份原有 .bashrc 至 ~/.bashrc.backup.*"
fi
if [[ -f "$SCRIPT_DIR/.bashrc" ]]; then
  cp "$SCRIPT_DIR/.bashrc" ~/.bashrc
else
  curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/.bashrc -o ~/.bashrc
fi

echo "✅ 完成！執行 source ~/.bashrc 生效"

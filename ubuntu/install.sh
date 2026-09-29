#!/usr/bin/env bash
# dotfiles/ubuntu/install.sh (Ubuntu 一鍵配置)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != Linux ]]; then
  echo "此腳本僅供 Ubuntu 使用。" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
else
  UBUNTU_CODENAME=""
fi
if [[ "${ID:-}" != ubuntu ]]; then
  echo "此腳本僅供 Ubuntu 使用。" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# 偵測架構
DPKG_ARCH=$(dpkg --print-architecture)
case "$DPKG_ARCH" in
  amd64)
    NVIM_ARCH="x86_64"
    LG_ARCH="x86_64"
    RG_ARCH="x86_64-unknown-linux-musl"
    FD_ARCH="x86_64-unknown-linux-musl"
    DELTA_ARCH="x86_64-unknown-linux-musl"
    ZJ_ARCH="x86_64-unknown-linux-musl"
    ;;
  arm64)
    NVIM_ARCH="arm64"
    LG_ARCH="arm64"
    RG_ARCH="aarch64-unknown-linux-musl"
    FD_ARCH="aarch64-unknown-linux-musl"
    DELTA_ARCH="aarch64-unknown-linux-gnu"
    ZJ_ARCH="aarch64-unknown-linux-musl"
    ;;
  *) echo "不支援的架構：$DPKG_ARCH"; exit 1 ;;
esac

# 保留官方 tag；HTTP / JSON 錯誤立即停止，避免拼出空白版本的下載網址。
_latest_v() {
  local tag
  tag=$(curl -fsSL --retry 3 "https://api.github.com/repos/$1/releases/latest" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])') || return 1
  if [[ ! "$tag" =~ ^v?[0-9]+(\.[0-9]+)+$ ]]; then
    echo "無效的版本：$1 / $tag" >&2
    return 1
  fi
  printf '%s\n' "$tag"
}
# 取得最新版本號（去除 v 前綴）
_latest()   { _latest_v "$1" | sed 's/^v//'; }

_install_tar_binary() {
  local repo="$1" tag="$2" archive="$3" member="$4" binary="$5" stage
  stage=$(mktemp -d "$WORK_DIR/release.XXXXXX")
  curl -fsSL --retry 3 "https://github.com/$repo/releases/download/$tag/$archive" -o "$stage/archive.tar.gz"
  tar -xzf "$stage/archive.tar.gz" -C "$stage" "$member"
  # 先檢查架構及 libc 相容性，成功後才替換現有執行檔。
  "$stage/$member" --version
  sudo install -m 0755 "$stage/$member" "/usr/local/bin/$binary"
}

echo "==> 更新套件"
sudo apt update -qq

echo "==> 安裝常用開發工具與系統 Python / OpenCV 開發依賴"
sudo apt install -y software-properties-common
sudo add-apt-repository -y universe
COMMON_DEV_PACKAGES=(
  build-essential
  git
  curl
  wget
  vim
  nano
  htop
  btop
  net-tools
  openssh-server
  cmake
  gdb
  unzip
  zip
  software-properties-common
  ca-certificates
  gawk
  gpg
  gnupg
  lsb-release
  pkg-config
  xclip
  wl-clipboard
)
SYSTEM_PYTHON_PACKAGES=(
  python3
  python-is-python3
  python3-venv
  python3-dev
  libopencv-dev
)
# Python 函式庫改由各專案的 uv 管理；不移除既有 apt / ROS 套件。
sudo apt install -y "${COMMON_DEV_PACKAGES[@]}" "${SYSTEM_PYTHON_PACKAGES[@]}"
unset COMMON_DEV_PACKAGES SYSTEM_PYTHON_PACKAGES

echo "==> 安裝 VS Code"
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
echo "deb [arch=$DPKG_ARCH signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
sudo apt update -qq
sudo apt install -y code

if [[ "$UBUNTU_CODENAME" == "jammy" ]]; then
  echo "==> 安裝 ROS 2 Humble"
  sudo apt install -y locales
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  sudo add-apt-repository -y universe
  ROS_APT_SOURCE_VERSION=$(_latest_v ros-infrastructure/ros-apt-source)
  curl -fsSL --retry 3 -o "$WORK_DIR/ros2-apt-source.deb" \
    "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${UBUNTU_CODENAME}_all.deb"
  sudo dpkg -i "$WORK_DIR/ros2-apt-source.deb"
  unset ROS_APT_SOURCE_VERSION
  sudo apt update -qq
  sudo apt install -y systemd udev
  sudo apt install -y \
    ros-humble-desktop \
    ros-dev-tools \
    python3-argcomplete \
    python3-colcon-common-extensions
  if command -v rosdep >/dev/null 2>&1; then
    if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
      sudo rosdep init
    fi
    rosdep update || echo "   rosdep update 失敗，可稍後手動執行 rosdep update"
  fi
else
  echo "==> 略過 ROS 2 Humble：Humble apt 套件目標是 Ubuntu 22.04 jammy，目前偵測為 ${UBUNTU_CODENAME:-unknown}"
fi

echo "==> 安裝 ripgrep"
RG_VER=$(_latest BurntSushi/ripgrep)
_install_tar_binary BurntSushi/ripgrep "$RG_VER" "ripgrep-${RG_VER}-${RG_ARCH}.tar.gz" "ripgrep-${RG_VER}-${RG_ARCH}/rg" rg

echo "==> 安裝 fd"
FD_VER=$(_latest sharkdp/fd)
_install_tar_binary sharkdp/fd "v$FD_VER" "fd-v${FD_VER}-${FD_ARCH}.tar.gz" "fd-v${FD_VER}-${FD_ARCH}/fd" fd

echo "==> 安裝 bat / dust / delta（官方預編譯版本）"
BAT_VER=$(_latest sharkdp/bat)
_install_tar_binary sharkdp/bat "v$BAT_VER" "bat-v${BAT_VER}-${FD_ARCH}.tar.gz" "bat-v${BAT_VER}-${FD_ARCH}/bat" bat
DUST_VER=$(_latest bootandy/dust)
_install_tar_binary bootandy/dust "v$DUST_VER" "dust-v${DUST_VER}-${FD_ARCH}.tar.gz" "dust-v${DUST_VER}-${FD_ARCH}/dust" dust
DELTA_VER=$(_latest dandavison/delta)
_install_tar_binary dandavison/delta "$DELTA_VER" "delta-${DELTA_VER}-${DELTA_ARCH}.tar.gz" "delta-${DELTA_VER}-${DELTA_ARCH}/delta" delta

git config --global --get core.pager >/dev/null || git config --global core.pager delta
git config --global --get interactive.diffFilter >/dev/null || git config --global interactive.diffFilter 'delta --color-only'
git config --global --get delta.side-by-side >/dev/null || git config --global delta.side-by-side true
git config --global --get delta.line-numbers >/dev/null || git config --global delta.line-numbers true
git config --global --get delta.syntax-theme >/dev/null || git config --global delta.syntax-theme Dracula

echo "==> 安裝 fzf"
FZF_VER=$(_latest junegunn/fzf)
_install_tar_binary junegunn/fzf "v$FZF_VER" "fzf-${FZF_VER}-linux_${DPKG_ARCH}.tar.gz" fzf fzf
# 現代 fzf 可直接產生 shell 整合，不再刪除 ~/.fzf 或保留第二份執行檔。

echo "==> 安裝 eza"
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
  | gpg --dearmor \
  | sudo tee /etc/apt/keyrings/gierens.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
  | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
sudo apt update -qq && sudo apt install -y eza

echo "==> 安裝 zoxide"
curl -fsSL --retry 3 https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$WORK_DIR/zoxide-install.sh"
bash "$WORK_DIR/zoxide-install.sh"

echo "==> 安裝 ble.sh"
BLE_SRC="$WORK_DIR/blesh"
git clone -q --recursive https://github.com/akinomyoga/ble.sh.git "$BLE_SRC"
make -C "$BLE_SRC" install PREFIX=~/.local --quiet
rm -rf "$BLE_SRC"
unset BLE_SRC

echo "==> 從源碼安裝 keyd"
KEYD_SRC="$WORK_DIR/keyd"
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

echo "==> 安裝 Neovim（官方 tarball，無需 FUSE，$DPKG_ARCH）"
NVIM_TAG=$(_latest_v neovim/neovim)
curl -fsSL --retry 3 -o "$WORK_DIR/nvim.tar.gz" \
  "https://github.com/neovim/neovim/releases/download/${NVIM_TAG}/nvim-linux-${NVIM_ARCH}.tar.gz"
tar -xzf "$WORK_DIR/nvim.tar.gz" -C "$WORK_DIR"
"$WORK_DIR/nvim-linux-${NVIM_ARCH}/bin/nvim" --version
NVIM_DEST="/opt/neovim/$NVIM_TAG/nvim-linux-$NVIM_ARCH"
if [[ ! -f "$NVIM_DEST/.dotfiles-complete" || ! -x "$NVIM_DEST/bin/nvim" ]]; then
  sudo install -d -m 0755 "$NVIM_DEST"
  sudo cp -R "$WORK_DIR/nvim-linux-${NVIM_ARCH}/." "$NVIM_DEST/"
  # 中途中斷的複製會在重跑時補齊；完成後才切換 nvim 連結。
  sudo touch "$NVIM_DEST/.dotfiles-complete"
fi
sudo ln -sfn "$NVIM_DEST/bin/nvim" /usr/local/bin/nvim

echo "==> 安裝 lazygit"
LAZYGIT_VERSION=$(_latest jesseduffield/lazygit)
_install_tar_binary jesseduffield/lazygit "v$LAZYGIT_VERSION" "lazygit_${LAZYGIT_VERSION}_linux_${LG_ARCH}.tar.gz" lazygit lazygit

echo "==> 安裝 zellij"
ZELLIJ_TAG=$(_latest_v zellij-org/zellij)
_install_tar_binary zellij-org/zellij "$ZELLIJ_TAG" "zellij-${ZJ_ARCH}.tar.gz" zellij zellij
unset ZELLIJ_TAG

echo "==> 安裝 nvm"
if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  curl -fsSL --retry 3 https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o "$WORK_DIR/nvm-install.sh"
  PROFILE=/dev/null bash "$WORK_DIR/nvm-install.sh"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if ! nvm use default; then
  nvm install --lts
fi

echo "==> 設定 uv Python 3.12 與 Neovim providers"
if [[ -f "$SCRIPT_DIR/../scripts/install-common.sh" ]]; then
  bash "$SCRIPT_DIR/../scripts/install-common.sh"
else
  curl -fsSL --retry 3 https://raw.githubusercontent.com/leimouhong/dotfiles/main/scripts/install-common.sh -o "$WORK_DIR/install-common.sh"
  bash "$WORK_DIR/install-common.sh"
fi

echo "==> 安裝 LazyVim"
if [[ -f "$SCRIPT_DIR/nvim/install.sh" ]]; then
  bash "$SCRIPT_DIR/nvim/install.sh"
else
  (
    NVIM_INSTALLER=$(mktemp)
    trap 'rm -f "$NVIM_INSTALLER"' EXIT
    curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/nvim/install.sh -o "$NVIM_INSTALLER"
    bash "$NVIM_INSTALLER"
  )
fi

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

########################################
# Tailscale（安裝最後詢問，預設略過）
########################################
echo "==> 可選：設定 Tailscale"
if [[ ! -t 0 ]]; then
  echo "   非互動式執行，略過 Tailscale 設定。"
elif read -r -p "是否安裝並啟用 Tailscale？[y/N] " TAILSCALE_REPLY &&
     [[ "$TAILSCALE_REPLY" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
  else
    echo "   Tailscale 已安裝，跳過安裝。"
  fi
  sudo systemctl enable --now tailscaled
  echo "   首次使用請開啟下方登入網址，完成 Tailscale 登入。"
  sudo tailscale up

  if read -r -p "是否將此裝置設為 Tailscale exit node？[y/N] " TAILSCALE_EXIT_NODE_REPLY &&
     [[ "$TAILSCALE_EXIT_NODE_REPLY" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "==> 啟用 exit node 所需的 IPv4 / IPv6 forwarding"
    # 專用檔案由 dotfiles 管理；重跑時覆寫，避免重複追加設定。
    sudo mkdir -p /etc/sysctl.d
    sudo tee /etc/sysctl.d/99-tailscale-dotfiles.conf >/dev/null <<'EOF'
# Managed by dotfiles/ubuntu/install.sh
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
    sudo sysctl -p /etc/sysctl.d/99-tailscale-dotfiles.conf
    # set 僅修改指定選項，保留既有 DNS、路由等偏好。
    sudo tailscale set --advertise-exit-node
    echo "   如未設定自動核准，請到 https://login.tailscale.com/admin/machines"
    echo "   選擇此裝置 → Edit route settings → 勾選 Use as exit node。"
  else
    echo "   略過 exit node 設定。"
  fi
  sudo tailscale status
else
  echo "   略過 Tailscale 設定。"
fi
unset TAILSCALE_REPLY TAILSCALE_EXIT_NODE_REPLY

echo "✅ 完成！執行 source ~/.bashrc 生效"

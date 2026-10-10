#!/usr/bin/env bash
# dotfiles/ubuntu/install.sh（安裝一次，執行 mouhong 按需啟用）
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
用法：bash ubuntu/install.sh [--computer | --robot]

  --computer  電腦：共用個人環境 + 桌面／開發套件
  --robot     機器人：共用個人環境，保留系統 Python、ROS 及廠商設定
  不加參數    互動選擇；非互動執行必須明確指定模式

兩種模式最後都會詢問是否啟用 Tailscale，以及是否使用
Hetzner 100.78.131.72 作為出口；非互動執行略過網路設定。
啟用時：電腦設定開機自啟，機器人只啟動本次、之後手動開啟。
EOF
}

select_profile() {
  INSTALL_PROFILE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --computer|--robot)
        if [[ -n "$INSTALL_PROFILE" ]]; then
          echo "請只選擇一種安裝模式。" >&2
          return 1
        fi
        INSTALL_PROFILE="${1#--}"
        ;;
      *) echo "不支援的參數：$1" >&2; return 1 ;;
    esac
    shift
  done
  if [[ -z "$INSTALL_PROFILE" ]]; then
    if [[ ! -t 0 ]]; then
      echo "非互動執行請指定 --computer 或 --robot。" >&2
      return 1
    fi
    local answer
    read -r -p "安裝到 1) 電腦  2) 機器人？（Enter 預設選電腦）：" answer
    case "${answer:-1}" in
      1|computer) INSTALL_PROFILE=computer ;;
      2|robot) INSTALL_PROFILE=robot ;;
      *) echo "無效的選擇。" >&2; return 1 ;;
    esac
  fi
  echo "==> 安裝模式：$INSTALL_PROFILE"
}

clear_proxy_environment() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY
}

install_base_packages() {
  local packages=(
    build-essential git curl wget vim nano htop btop net-tools openssh-server
    cmake gdb unzip zip ca-certificates gawk gpg gnupg lsb-release pkg-config
  )
  if [[ "$INSTALL_PROFILE" == computer ]]; then
    packages+=(xclip wl-clipboard python3 python-is-python3 python3-venv python3-dev libopencv-dev)
  fi
  # 不移除或改版機器人現有的 Python、OpenCV、ROS 套件。
  sudo apt install -y "${packages[@]}"
}

confirm() {
  local answer
  [[ -t 0 ]] || return 1
  read -r -p "$1 [y/N] " answer && [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

configure_tailscale() (
  set -euo pipefail
  echo "==> 可選：設定 Tailscale"
  local prompt="是否安裝並啟用 Tailscale（電腦會設定開機自啟）？"
  if [[ "$INSTALL_PROFILE" == robot ]]; then
    prompt="是否安裝並啟用 Tailscale（機器人只啟動本次，之後手動開啟）？"
  fi
  if ! confirm "$prompt"; then
    echo "   略過 Tailscale，保留目前網路設定。"
    return 0
  fi
  if ! command -v tailscale >/dev/null 2>&1; then
    local stage
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    curl -fsSL --retry 3 https://tailscale.com/install.sh -o "$stage/install.sh"
    sh "$stage/install.sh"
  fi
  if [[ "$INSTALL_PROFILE" == robot ]]; then
    # 官方套件可能預設自啟；新裝及重跑都取消自啟，但不切斷目前連線。
    sudo systemctl disable tailscaled
    sudo systemctl start tailscaled
    # 連線前先保留原本 DNS，避免接收其他設備宣告的子網路路由。
    sudo tailscale set --accept-dns=false --accept-routes=false
    echo "   已取消開機自啟。本次啟用後，下次開機需手動執行："
    echo "   sudo systemctl start tailscaled && sudo tailscale up"
  else
    sudo systemctl enable --now tailscaled
  fi
  echo "   首次使用請開啟下方登入網址，完成 Tailscale 登入。"
  # 不帶偏好旗標，重跑時保留既有設定；指定偏好一律用 set 更新。
  sudo tailscale up
  if confirm "是否使用 Hetzner（100.78.131.72）作為 exit node？N 保留目前出口設定。"; then
    sudo tailscale set --exit-node=100.78.131.72 --exit-node-allow-lan-access=true
    echo "   已選用 Hetzner，並允許存取本地 LAN。"
  else
    echo "   保留目前出口設定。"
  fi
  sudo tailscale status
)

install_codex() (
  set -euo pipefail
  if ! type -P codex >/dev/null 2>&1; then
    npm install --global @openai/codex@latest
  fi
  command codex --version
  local config_dir="${CODEX_HOME:-$HOME/.codex}"
  mkdir -p "$config_dir"
  if [[ -e "$config_dir/config.toml" || -L "$config_dir/config.toml" ]]; then
    echo "   保留原有 Codex 設定及登入資料。"
    return 0
  fi
  # 延續原有 Robot 的初始偏好；日誌使用 Codex 的使用者預設目錄。
  cat > "$config_dir/config.toml" <<'EOF'
approval_policy = "never"
sandbox_mode = "danger-full-access"
model_reasoning_effort = "xhigh"
web_search = "live"

[tui]
alternate_screen = "never"
animations = false
EOF
)

# 以函式分段，整個 Ubuntu 安裝只有這個主入口。
# 子 Shell 讓暫存目錄與 trap 不會影響主安裝流程。
install_personal_environment() (
  set -euo pipefail
  CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  CONFIG_DIR="$CONFIG_HOME/mouhong"
  mkdir -p "$CONFIG_DIR/zellij" "$HOME/.local/bin"
  WORK_DIR=$(mktemp -d "$CONFIG_DIR/.install.XXXXXX")
  trap 'rm -rf "$WORK_DIR"' EXIT

  cp "$SCRIPT_DIR/.bashrc" "$WORK_DIR/bashrc"
  cp "$SCRIPT_DIR/mouhong" "$WORK_DIR/mouhong"
  cp "$SCRIPT_DIR/../zellij/config.kdl" "$WORK_DIR/config.kdl"
  printf '%s\n' "${INSTALL_PROFILE:-computer}" > "$WORK_DIR/profile"
  # Zellij 每個新窗格都從入口載入個人 Bash，不會回到原有 ~/.bashrc。
  printf '\n// Ubuntu 個人環境的新窗格\ndefault_shell "/usr/local/bin/mouhong"\n' >> "$WORK_DIR/config.kdl"
  bash -n "$WORK_DIR/bashrc"
  bash -n "$WORK_DIR/mouhong"
  zellij --config "$WORK_DIR/config.kdl" setup --check

  # 只備份及更新自己的檔案，原有 Bash / Zellij 設定不在部署目標中。
  for config_name in bashrc zellij/config.kdl profile; do
    stage_name="${config_name##*/}"
    if ! cmp -s "$WORK_DIR/$stage_name" "$CONFIG_DIR/$config_name"; then
      if [[ -e "$CONFIG_DIR/$config_name" || -L "$CONFIG_DIR/$config_name" ]]; then
        backup_file=$(mktemp "$CONFIG_DIR/$config_name.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
        cp -P "$CONFIG_DIR/$config_name" "$backup_file"
      fi
      mv -f "$WORK_DIR/$stage_name" "$CONFIG_DIR/$config_name"
    fi
  done

  bash "$SCRIPT_DIR/nvim/install.sh"
  # /usr/local/bin 在 Ubuntu 的預設 PATH 中，新 SSH 連線不用修改啟動檔。
  sudo install -m 0755 "$WORK_DIR/mouhong" /usr/local/bin/mouhong
  echo "✅ 個人環境已安裝。執行 mouhong 啟用，exit 返回原本 Shell。"
)

install_fcitx5() (
  set -euo pipefail
  if [[ $EUID -eq 0 ]]; then
    echo "請以一般使用者執行此腳本，套件安裝會自行使用 sudo。" >&2
    exit 1
  fi

  sudo apt install -y \
    fcitx5 fcitx5-pinyin fcitx5-chinese-addons fcitx5-config-qt \
    fcitx5-frontend-gtk2 fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5 im-config

  # im-config 自行處理桌面啟動及 GTK / Qt / XIM 變數；不寫入 Shell 啟動檔。
  if [[ -f "$HOME/.xinputrc" ]]; then
    backup_file=$(mktemp "$HOME/.xinputrc.backup.$(date +%Y%m%d_%H%M%S).XXXXXX")
    cp -p "$HOME/.xinputrc" "$backup_file"
  fi
  if ! im-config -n fcitx5; then
    echo "im-config 未能切換輸入法（可能已有手動設定的 ~/.xinputrc）。" >&2
    echo "請檢查原設定後執行 im-config 選擇 Fcitx5；原設定保留。" >&2
    exit 1
  fi

  FCITX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5"
  mkdir -p "$FCITX_DIR"
  if [[ ! -e "$FCITX_DIR/profile" && ! -L "$FCITX_DIR/profile" ]]; then
    cat > "$FCITX_DIR/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
EOF
  else
    echo "   保留既有 Fcitx5 輸入法清單；如未有 Pinyin，請用 fcitx5-configtool 加入。"
  fi

  echo "✅ 已安裝 Fcitx5 + Pinyin；請登出 Ubuntu 圖形桌面後重新登入。"
  echo "   預設 Ctrl+Space 切換；設定：fcitx5-configtool；診斷：fcitx5-diagnose。"
)

# 允許測試只載入函式；直接執行時才進行系統安裝。
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi
if [[ ${1:-} == -h || ${1:-} == --help ]]; then
  usage
  exit 0
fi
select_profile "$@"
if [[ "$INSTALL_PROFILE" == robot ]]; then
  # 不沿用呼叫端先前 proxy_on 匯出的 Mac 代理；不修改父 Shell。
  clear_proxy_environment
fi

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
if [[ $EUID -eq 0 ]]; then
  echo "請以一般使用者執行 bash ubuntu/install.sh；需要管理員權限時會使用 sudo。" >&2
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

echo "==> 安裝共用開發工具與所選模式的依賴"
sudo apt install -y software-properties-common
sudo add-apt-repository -y universe
install_base_packages
if ! command -v python3 >/dev/null 2>&1; then
  echo "本安裝器需要 Ubuntu 現有的 python3；機器人模式不自行更換系統 Python。" >&2
  exit 1
fi

# 線上入口也先取得完整部署檔案，所有設定使用同一份 checkout。
if [[ ! -f "$SCRIPT_DIR/mouhong" || ! -f "$SCRIPT_DIR/migrate-bashrc.py" ]]; then
  git clone -q --depth 1 https://github.com/leimouhong/dotfiles.git "$WORK_DIR/dotfiles"
  SCRIPT_DIR="$WORK_DIR/dotfiles/ubuntu"
fi
python3 "$SCRIPT_DIR/migrate-bashrc.py"

if [[ "$INSTALL_PROFILE" == computer ]]; then
  echo "==> 安裝桌面 Fcitx5 + Pinyin"
  install_fcitx5

  echo "==> 安裝 VS Code"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
  echo "deb [arch=$DPKG_ARCH signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt update -qq
  sudo apt install -y code
fi

if [[ "$INSTALL_PROFILE" == computer && "$UBUNTU_CODENAME" == jammy ]]; then
  echo "==> 安裝 ROS 2 Humble"
  sudo apt install -y locales
  sudo locale-gen en_US en_US.UTF-8
  # 只產生 ROS 可用的 locale，保留 Ubuntu 原本的全域語系。
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
  echo "==> 略過 ROS 2 Humble（僅電腦模式的 Ubuntu 22.04 安裝）"
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

if [[ "$INSTALL_PROFILE" == computer ]]; then
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

  # keyd 是整台電腦的鍵盤服務，無法隨子 Shell 的 exit 還原。
  # 僅安裝程式，不覆寫 /etc/keyd/default.conf，也不自動啟用服務。
  echo "   keyd 已安裝；需要 Tab + hjkl 時可依 README 手動啟用。"
fi

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
(
  set -euo pipefail

  WORK_DIR=$(mktemp -d)
  trap 'rm -rf "$WORK_DIR"' EXIT
  export PATH="$HOME/.local/bin:$PATH"
  export UV_TOOL_BIN_DIR="$HOME/.local/bin"

  if ! command -v uv >/dev/null 2>&1; then
    curl -fsSL --retry 3 https://astral.sh/uv/install.sh -o "$WORK_DIR/uv-install.sh"
    UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$WORK_DIR/uv-install.sh"
  fi

  echo "==> uv 安裝 Python 3.12 與 pynvim"
  # uv 管理的 Python 僅供個人工具使用，保留 Ubuntu／機器人的系統 python3。
  uv python install 3.12
  PYTHON=$(uv python find --managed-python 3.12)
  PIPX_PYNVIM=0
  if command -v pipx >/dev/null 2>&1; then
    pipx list --json > "$WORK_DIR/pipx.json"
    PIPX_PYNVIM=$("$PYTHON" -c 'import json, sys; print(int("pynvim" in json.load(open(sys.argv[1]))["venvs"]))' "$WORK_DIR/pipx.json")
  fi

  if [[ "$PIPX_PYNVIM" == 1 ]]; then
    # 先準備並驗證 uv 環境，再移除 pipx 的 pynvim；不影響其他 pipx 工具。
    UV_TOOL_BIN_DIR="$WORK_DIR/bin" uv tool install --force --managed-python --python 3.12 'pynvim>=0.6.0'
    "$(uv tool dir)/pynvim/bin/python" -c 'import pynvim, sys; assert sys.version_info[:2] == (3, 12)'
    pipx uninstall pynvim
    uv tool install --force --offline --managed-python --python 3.12 'pynvim>=0.6.0'
  else
    uv tool install --managed-python --python 3.12 'pynvim>=0.6.0'
  fi
  "$(uv tool dir)/pynvim/bin/python" -c 'import pynvim, sys; assert sys.version_info[:2] == (3, 12)'

  echo "==> 安裝目前 Node 版本的 Neovim provider"
  npm install --global neovim
  # LazyVim / nvim-treesitter 編譯 parser 使用。
  npm install --global tree-sitter-cli

  echo "==> 驗證 Neovim 的 Python / Node provider"
  cat > "$WORK_DIR/check-provider.lua" <<'LUA'
vim.g.python3_host_prog = vim.fn.expand("~/.local/bin/pynvim-python")
assert(vim.fn.has("python3") == 1, "Python provider unavailable")
assert(vim.fn.py3eval("6 * 7") == 42, "Python evaluation failed")
local version = vim.fn.py3eval('__import__("sys").version.split()[0]')
assert(version:match("^3%.12%."), "Expected Python 3.12, got " .. version)
vim.cmd([[python3 vim.vars['provider_check'] = 'ok']])
assert(vim.g.provider_check == "ok", "Python RPC failed")
assert(vim.fn["provider#node#Prog"]() ~= "", "Node provider unavailable")
local channel = vim.fn["remote#host#Require"]("node")
assert(channel > 0 and vim.fn.rpcrequest(channel, "poll") == "ok", "Node RPC failed")
print("Neovim providers OK; Python " .. version)
LUA
  nvim --headless -u NONE -i NONE -n -l "$WORK_DIR/check-provider.lua"
)

echo "==> 安裝 mouhong 個人環境（Bash / LazyVim / Zellij）"
install_personal_environment

echo "==> 安裝 Codex CLI"
install_codex

# 兩種模式都在全部工具部署後才詢問；不提供本機 exit node 宣告功能。
configure_tailscale

echo "✅ 安裝完成（$INSTALL_PROFILE）！執行 mouhong 啟用，exit 返回原本 Shell。"
echo "   SSH 登入不會自動啟用；舊版使用者請重新開啟終端／SSH 連線。"
if [[ "$INSTALL_PROFILE" == computer ]]; then
  echo "   Fcitx5 請登出圖形桌面後重新登入。"
fi

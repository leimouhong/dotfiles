# dotfiles

macOS、Ubuntu 電腦與機器人的個人終端環境。

## 安裝

在專案根目錄，以一般使用者執行，依平台擇一：

```bash
bash mac/install.sh                 # macOS
bash ubuntu/install.sh --computer   # Ubuntu 電腦
bash ubuntu/install.sh --robot      # Ubuntu 機器人
```

Ubuntu 支援 22.04／24.04、amd64／arm64；省略參數會詢問安裝模式。需要先能連網，安裝過程會使用 `sudo`。

也可直接執行 GitHub `main` 上的版本：

```bash
# macOS
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/install.sh)

# Ubuntu：互動選擇電腦或機器人
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/install.sh)
```

| Ubuntu 安裝內容 | 電腦 | 機器人 |
| --- | --- | --- |
| mouhong、ble.sh、fzf、eza、zoxide、Zellij、Codex CLI、Claude Code、LazyVim | ✓ | ✓ |
| Git／C/C++ 工具、nvm、uv Python 3.12／Neovim provider | ✓ | ✓ |
| 系統 Python／OpenCV 開發套件、VS Code、Fcitx5 拼音 | ✓ | 不安裝 |
| ROS 2 Humble | 僅 22.04 | 不安裝／不自動載入 |
| keyd | 安裝、套用映射並開機自啟 | 不安裝 |

機器人保留原有系統 Python、ROS 及廠商設定；個人工具的 Python 由 uv 獨立管理。Mac 使用 Zsh，會備份並更新 `.zshrc`／`.zprofile`，以 uv 設定使用者預設 Python 3.12，最後啟用 Tailscale。

Mac 與兩種 Ubuntu 模式都會安裝 Claude Code，採用[官方原生安裝方式](https://code.claude.com/docs/en/setup)；已有安裝時保留原版本、設定及登入資料。執行 `claude`，首次使用依提示登入。

## Ubuntu 日常使用

```bash
mouhong   # 進入個人 Bash
nvim      # 個人 LazyVim
zellij    # 個人 Zellij
codex     # 首次使用依提示登入
claude    # Claude Code，首次使用依提示登入
exit      # 返回原本 Shell
```

SSH 登入及一般終端不會自動啟用個人環境。`exit` 還原原本 Shell 的環境；套件、輸入法、keyd 及 Tailscale 獨立運作。在 Zellij 內 `exit` 只關閉窗格，離開 Zellij 後再退出個人 Shell。

個人設定位於 `~/.config/mouhong/`，Neovim 位於 `~/.config/nvim-mouhong/`（支援自訂 XDG 目錄）；原有 Bash、Neovim、Zellij 及 Codex 設定會保留。舊版升級會備份並遷移可辨識的個人 Bash／robot 代理區塊；完成後重新開啟終端或 SSH。

電腦安裝 Fcitx5 後，**登出圖形桌面再登入**；`Ctrl+Space` 切換輸入法，`fcitx5-configtool` 管理拼音。keyd 會備份並部署 [default.conf](ubuntu/keyd/default.conf)，立即啟用並設定開機自啟；按住 `Tab` 配合 `h/j/k/l` 輸入方向鍵，單按仍是 Tab。

## Tailscale

Ubuntu 安裝最後會詢問是否啟用 Tailscale，以及是否選用 **`hetzner`（`100.78.131.72`）** 作為 exit node。兩項預設皆否；略過會保留現有設定。

- **電腦**：選擇啟用後設定開機自啟。
- **機器人**：選擇啟用後只啟動本次，取消開機自啟；保留 DNS、不接受其他設備的子網路路由。
- 選用 Hetzner 時，兩種模式都允許存取本地 LAN。機器人不再使用 `proxy_on` 或 Mac 代理。

機器人手動啟動：

```bash
sudo systemctl start tailscaled
sudo tailscale up
```

使用完畢後關閉：

```bash
sudo tailscale down
sudo systemctl stop tailscaled
```

`--accept-dns=false`、`--accept-routes=false`、exit node 及 `--exit-node-allow-lan-access=true` 設定會保存，停止服務或重開機後不用重設。連線後可用 `tailscale status` 查看狀態。

安裝時選用 Hetzner 已設定允許本地 LAN。Tailscale 已連線時，只需切換出口，LAN／DNS／子網路路由偏好都會保留：

```bash
# 關閉 exit node，恢復使用本機網路出口
sudo tailscale set --exit-node=

# 開啟 Hetzner exit node
sudo tailscale set --exit-node=hetzner
```

機器人平時停止背景服務，以減少虛擬網路介面對 ROS 2／DDS 的影響；不採用背景服務自啟後再 `down`。`mouhong`／`exit` 不會切換 Tailscale。

## 清理備份

```bash
bash scripts/clean-backups.sh --dry-run   # 預覽
bash scripts/clean-backups.sh             # 刪除符合規則的安裝備份
```

只清理可辨識的設定備份，包含舊版備份；保留目前配置、登入資料及 Tailscale 狀態。

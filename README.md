# dotfiles

macOS、Ubuntu 與 Ubuntu 機器人的 shell、終端及開發環境設定。安裝前會備份既有設定；下列線上命令使用 GitHub `main`，本機修改需先提交並推送。

## 安裝

macOS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/install.sh)
source ~/.zshrc
```

Ubuntu 22.04／24.04（amd64／arm64）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/install.sh)
source ~/.bashrc
```

Ubuntu 機器人：先完成下方的 [Mac 準備](#mac-準備)，再選一種下載方式。腳本只詢問 Mac 網線 IP。

透過機器人自己的 Wi-Fi 下載（需能連到 GitHub）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/robot/install.sh)
source ~/.bashrc
```

透過 Mac 代理下載（將 `192.168.10.10` 換成實際的 Mac 網線 IP）：

```bash
bash <(curl -fsSL --proxy http://192.168.10.10:8888 --noproxy "" https://raw.githubusercontent.com/leimouhong/dotfiles/main/robot/install.sh)
source ~/.bashrc
```

| 安裝項目 | 內容 |
| --- | --- |
| Mac／Ubuntu 共用 | eza、fzf、fd、ripgrep、zoxide、zellij、Neovim、lazygit、nvm／Node.js LTS |
| Mac | zsh、zinit、starship、fastfetch、tinyproxy、Tailscale |
| Ubuntu | bash、ble.sh、LazyVim、keyd、VS Code、SSH server、C/C++、Python／OpenCV；22.04 另裝 ROS 2 Humble；最後詢問是否啟用 Tailscale／設定 exit node |
| Robot | Mac 代理設定、Codex CLI |

## 機器人設定

### Mac 準備

1. 用網線連接機器人，Mac 保持 Wi-Fi／其他上網連線。在「系統設定 → 網路 → 有線網路」手動設定 IPv4：Mac IP 例如 `192.168.10.10`、遮罩 `255.255.255.0`，路由器留空；機器人 IP 為 `192.168.10.102`。
2. 執行上方的 Mac 安裝命令，或在專案根目錄執行 `bash mac/install.sh`。按提示輸入兩端 IP，腳本會安裝 tinyproxy，監聽所有介面的 `8888` 埠，並只放行本機與機器人。監聽 `0.0.0.0` 是為了在未插上拓展塢、Mac 還沒有網線 IP 時也能成功啟動。
3. 在 Mac 載入設定、啟動並檢查 tinyproxy：

```bash
source ~/.zshrc
brew services restart tinyproxy
brew services info tinyproxy
```

確認 `Running: true`；Mac 防火牆詢問時允許 tinyproxy 傳入連線。tinyproxy 讓機器人的 HTTP／HTTPS 請求經 Mac 連外，設定檔位於 `$(brew --prefix)/etc/tinyproxy/tinyproxy.conf`。

若 Mac 使用 Tailscale Exit Node，保持 **Allow Local Network Access** 開啟，再執行 `proxy_robot`，先重啟 Tinyproxy，成功後輸入 Mac 網線 IP，為 `192.168.10.102` 建立直連路由；重開機或網路重設後可重新執行。

### Robot 使用

支援 x86_64／ARM64 Ubuntu。完成 Mac 準備後，在機器人使用上方的線上安裝命令，或在專案根目錄執行：

```bash
bash robot/install.sh
source ~/.bashrc
codex
```

腳本經 Mac 代理安裝 [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)，代理設定直接寫入 `.bashrc`，重跑只更新標記區塊。只需代理時加 `--proxy-only` 並省略 `codex`；未安裝 curl 時，可先從 Mac 經 SCP 傳入 `robot/install.sh`。

切換上網方式：

```bash
proxy_off  # 關閉代理，使用機器人自己的 Wi-Fi／系統網路
proxy_on   # 改回 Mac 代理
```

新開終端或 `source ~/.bashrc` 預設關閉代理，不保存開關狀態。切換只影響目前終端及之後啟動的程式；`proxy_off` 使用機器人已連接的 Wi-Fi／其他網路，不會自動連接 Wi-Fi。

## 單獨安裝

zellij（Mac）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/install.sh)
source ~/.zshrc
```

zellij（Ubuntu／Bash）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/install.sh)
source ~/.bashrc
```

LazyVim 設定（Ubuntu，需先安裝 Neovim）：關閉 Neovim，在專案根目錄執行。Ubuntu 完整安裝已包含此步驟。

```bash
bash ubuntu/nvim/install.sh
source ~/.bashrc
```

腳本備份後套用至 `${XDG_CONFIG_HOME:-$HOME/.config}/nvim`。首次開啟 `nvim`，等待外掛安裝，再執行 `:Lazy restore` 與 `:LazyHealth`；缺少的工具依提示補齊。

## Tailscale

- **Mac**：完整安裝會啟用 Tailscale，首次使用需登入。優先使用 Tailscale App；依提示允許網路擴充功能及 VPN。已有 Homebrew 命令列版時會沿用。
- **Ubuntu**：腳本最後會詢問是否安裝並啟用 Tailscale，預設為否；同意後才安裝、啟動服務並登入，再詢問是否將此裝置設為 exit node，預設也為否。只有同意設定 exit node 才會啟用 IPv4／IPv6 forwarding 並公告。非互動式執行會略過 Tailscale 設定。若未自動核准，到 [管理後台](https://login.tailscale.com/admin/machines) → 裝置 → **Edit route settings** → **Use as exit node**。

以 `tailscale status` 檢查連線。Mac 未安裝 CLI integration 時，使用 `/Applications/Tailscale.app/Contents/MacOS/Tailscale status`；App 裝於家目錄時改用 `~/Applications`。

## 清理備份

在專案根目錄執行：

```bash
bash cleanup-backups.sh --dry-run  # 預覽
bash cleanup-backups.sh           # 刪除
```

也可線上執行，移除 `--dry-run` 即刪除：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/cleanup-backups.sh) --dry-run
```

清理範圍包含 `.zshrc`、`.bashrc`（含 Robot）、zellij、keyd、tinyproxy 與 LazyVim 的安裝備份。只匹配各腳本的時間戳及六位隨機後綴格式；tinyproxy 路徑依 Homebrew 判斷，keyd 備份可能需要 `sudo`。

## 從 Mac 同步 LazyVim

在 Mac 的專案根目錄回存設定；`--delete` 會同步刪除來源已移除的 Lua 檔案：

```bash
rsync -av --delete "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lua/" ubuntu/nvim/config/lua/
cp "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json" \
   "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazyvim.json" ubuntu/nvim/config/
git diff -- ubuntu/nvim/
git add ubuntu/nvim/
git commit -m "Update LazyVim configuration"
git push
```

若修改 `init.lua`、`.neoconf.json` 或 `stylua.toml`，也需回存；保留專案 `init.lua` 依家目錄判斷 Python provider 的寫法。接著在 Ubuntu 的專案根目錄執行：

```bash
git pull
bash ubuntu/nvim/install.sh
source ~/.bashrc
```

## 常用快捷鍵

| 快捷鍵 | 功能 |
| --- | --- |
| `Opt-X`／`Alt-X` | 搜尋檔案並插入路徑 |
| `Opt-C`／`Alt-C` | 搜尋並切換目錄 |
| `↑`／`↓` | 依已輸入文字搜尋歷史 |
| `Ctrl-R`（Ubuntu） | fzf 搜尋歷史 |
| 按住 `Tab` + `h/j/k/l`（Ubuntu） | keyd 方向鍵；單按仍是 Tab |

zellij 使用 tokyo-night 主題；autolock 讓 Neovim、fzf 等程式直接接收快捷鍵。

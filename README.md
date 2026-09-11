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

Ubuntu 機器人：先透過機器人自己的 Wi-Fi 下載腳本，需能連到 GitHub。腳本啟動後才詢問兩端 IP，設定 Mac 代理並下載安裝套件；請先準備好 Mac 的 tinyproxy 與網線連線。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/robot/install.sh)
source ~/.bashrc
```

| 安裝項目 | 內容 |
| --- | --- |
| Mac／Ubuntu 共用 | eza、fzf、fd、ripgrep、zoxide、zellij、Neovim、lazygit、nvm／Node.js LTS、Tailscale |
| Mac | zsh、zinit、starship、fastfetch、tinyproxy |
| Ubuntu | bash、ble.sh、LazyVim、keyd、VS Code、SSH server、C/C++、Python／OpenCV、Tailscale exit node；22.04 另裝 ROS 2 Humble |
| Robot | Mac 代理設定、Codex CLI |

## 機器人設定

Mac 保持 Wi-Fi／其他上網連線，將連接機器人的乙太網路手動設為同一網段。預設範例：Mac `192.168.10.10`、機器人 `192.168.10.102`、遮罩 `255.255.255.0`；專用直連網線的路由器欄位留空。兩端安裝會詢問 IP，不修改網卡設定。

`mac/tinyproxy.conf` 參照 `/opt/homebrew/etc/tinyproxy/tinyproxy.conf` 的完整設定與註解。Mac 安裝會代入 IP 和 Homebrew 路徑，備份後寫入 `$(brew --prefix)/etc/tinyproxy/tinyproxy.conf`，監聽 Mac 網線 IP 的 `8888`，允許 loopback 及指定機器人 IP。若尚未接線，設好 IP 後執行 `brew services restart tinyproxy`；防火牆詢問時允許 tinyproxy 傳入連線。

線上安裝使用上方命令。已有專案時，在各自的專案根目錄執行：

```bash
# Mac
bash mac/install.sh
source ~/.zshrc
```

```bash
# Ubuntu 機器人
bash robot/install.sh
source ~/.bashrc
codex
```

機器人腳本支援 x86_64／ARM64 Ubuntu，經代理補裝 curl、CA 憑證及 [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)。代理設定與切換函式直接寫入 `.bashrc` 的標記區塊，重跑只更新該區塊，保留其他設定；只需代理時，在安裝命令後加 `--proxy-only` 並省略 `codex`。未安裝 curl 時，可先從 Mac 經 SCP 傳入 `robot/install.sh`。

切換上網方式（更新已有設定時，先重跑 Robot 安裝並 `source ~/.bashrc`）：

```bash
proxy off     # 關閉代理，使用機器人自己的 Wi-Fi／系統網路
proxy on      # 改回 Mac 代理
proxy status  # 查看目前終端及新終端的設定
```

切換會記住狀態，新開終端自動沿用；其他已開啟的終端及程式需重新載入或啟動。`proxy off` 不會自動連接 Wi-Fi，需先確認機器人的 Wi-Fi 與預設路由可上網。

在機器人檢查 Mac 代理及 HTTPS 下載：

```bash
source ~/.bashrc
proxy on
curl -fsS --proxy "$http_proxy" --noproxy "" http://tinyproxy.stats/
curl -fsSL --connect-timeout 10 --max-time 60 https://chatgpt.com/codex/install.sh -o /dev/null
codex --version
```

- 連線拒絕／逾時：檢查網線、兩端 IP、Mac 防火牆及 `brew services info tinyproxy`。HTTP 403：確認機器人 IP 與 `Allow` 一致。
- HTTP／HTTPS 代理均為 `http://<Mac IP>:8888`；`no_proxy` 保留既有例外並加入 localhost、loopback 及兩端 IP。
- 若 Ubuntu 完整安裝覆蓋 `.bashrc`，重跑 Robot 安裝以恢復代理設定與切換函式。
- `sudo apt` 通常不保留代理；Robot 腳本僅為自己的 apt 指令傳入代理，未修改全系統 APT 設定。

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

Mac／Ubuntu 完整安裝會啟用 Tailscale，首次使用需登入：

- **Mac**：優先使用 Tailscale App；依提示允許網路擴充功能及 VPN。已有 Homebrew 命令列版時會沿用。
- **Ubuntu**：啟動 `tailscaled`，啟用 IPv4／IPv6 forwarding，並公告為 exit node。若未自動核准，到 [管理後台](https://login.tailscale.com/admin/machines) → 裝置 → **Edit route settings** → **Use as exit node**。

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

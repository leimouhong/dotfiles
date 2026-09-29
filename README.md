# dotfiles

macOS、Ubuntu 開發機與 Ubuntu 機器人的終端設定。

## 安裝方式

線上指令使用 GitHub `main`；尚未推送的修改請使用本機專案安裝。Mac／Robot 腳本需要互動式終端輸入 IP，Ubuntu 安裝需要 `sudo`。

| 設定 | 適用環境 | 安裝內容 |
| --- | --- | --- |
| [macOS](#macos) | Apple Silicon／Intel Mac | zsh、常用 CLI、Neovim、zellij、uv、tinyproxy、Tailscale |
| [Ubuntu](#ubuntu) | Ubuntu 22.04／24.04，amd64／arm64 | Bash、常用 CLI、LazyVim、zellij、uv、VS Code、開發工具；22.04 加入 ROS 2 Humble |
| [Robot](#robot) | Ubuntu 機器人，x86_64／ARM64 | Mac 代理、zellij、Codex；保留原有 shell、ROS 與廠商設定 |

### macOS 完整安裝

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/install.sh)
source ~/.zshrc
```

會詢問 Mac 網線 IP、機器人 IP，設定並啟動 tinyproxy；最後啟用 Tailscale，首次使用需完成登入。既有 `.zshrc` 備份後會套用本專案版本；Neovim 的個人設定沿用原有內容。

### Ubuntu 完整安裝

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/install.sh)
source ~/.bashrc
```

會備份並套用 `.bashrc`、LazyVim、zellij 與 keyd 設定。最後可選擇啟用 Tailscale／exit node，預設皆為否。已有 ROS／廠商環境的機器人請使用下方 Robot 安裝。

### Robot 安裝

先在 Mac 完成 tinyproxy 設定，保持 Mac 能上網，再用網線連接機器人：

- Mac 有線 IPv4：例如 `192.168.10.10`，遮罩 `255.255.255.0`，路由器留空。
- Robot 固定 IP：目前腳本使用 `192.168.10.102`。
- 在 Mac 執行 `brew services info tinyproxy`，確認服務運行；macOS 防火牆詢問時允許傳入連線。

在機器人上透過 Mac 下載並安裝；將代理 IP 換成實際的 Mac 網線 IP：

```bash
bash <(curl -fsSL --proxy http://192.168.10.10:8888 --noproxy "" \
  https://raw.githubusercontent.com/leimouhong/dotfiles/main/robot/install.sh)
source ~/.bashrc
```

機器人自己的網路可連 GitHub 時，可省略下載指令的 `--proxy … --noproxy ""`；腳本執行後仍會詢問 Mac IP，並使用 Mac 代理安裝。只設定代理時，在上述指令最後加上 `--proxy-only`，便會略過 zellij／Codex。

### 從本機專案安裝

下載專案後，依目標平台選擇一個入口：

```bash
git clone https://github.com/leimouhong/dotfiles.git
cd dotfiles
```

| 用途 | 在專案根目錄執行 | 安裝後載入 |
| --- | --- | --- |
| Mac 完整環境 | `bash mac/install.sh` | `source ~/.zshrc` |
| Ubuntu 完整環境 | `bash ubuntu/install.sh` | `source ~/.bashrc` |
| Robot 環境 | `bash robot/install.sh` | `source ~/.bashrc` |
| Robot 只設定代理 | `bash robot/install.sh --proxy-only` | `source ~/.bashrc` |

已有本機修改時，使用該份專案；Robot 沒有 curl 時，也可先從 Mac 用 SCP 傳入 `robot/install.sh`，腳本會補裝 curl。

### 單獨安裝元件

**zellij（Mac／Ubuntu）**：安裝缺少的執行檔並套用共用設定；不同的舊設定會先備份。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/install.sh)
```

本機入口：`bash zellij/install.sh`。已有版本會沿用；需要重裝時使用 `ZELLIJ_REINSTALL=1 bash zellij/install.sh`。

**LazyVim 設定（Ubuntu）**：需已有 Neovim、Git 與相關依賴；先關閉 Neovim，再執行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/nvim/install.sh)
```

本機入口：`bash ubuntu/nvim/install.sh`。設定備份後套用至 `${XDG_CONFIG_HOME:-$HOME/.config}/nvim`；Ubuntu 完整安裝已包含此步驟。

**uv／Neovim providers（Mac／Ubuntu）**：完整安裝已包含。需已有 Neovim、可用的 Node／npm；Mac 另需 Homebrew。從專案根目錄補裝或重新驗證：

```bash
bash scripts/install-common.sh
```

## 功能與快捷鍵

### macOS

設定檔：[mac/.zshrc](mac/.zshrc)。

- zinit 管理補全、自動建議、語法高亮與 fzf-tab；Starship 顯示提示列，fastfetch 在頂層終端顯示系統資訊。
- 多終端共享歷史，空格開頭的指令不保存；nvm 與既有 Conda 採延遲載入。
- 使用 Homebrew 管理 CLI；偵測既有 Kaku 整合，最後套用個人 eza 別名。
- 預設編輯器為 `code -w`，需自行提供 VS Code 的 `code` 指令。

| 快捷鍵 | 功能 |
| --- | --- |
| `Tab` | fzf-tab 補全；選單內用 `Tab`／`Shift+Tab` 切換群組 |
| `Option+←`／`Option+→` | 以單字移動游標 |

搜尋、歷史與目錄跳轉見下方共用設定。Option 組合鍵需由終端送出 Alt／Meta；`Option+x`／`Option+c` 也可用先按 `Esc` 再按 `x`／`c`。

### Ubuntu

設定檔：[ubuntu/.bashrc](ubuntu/.bashrc)、[ubuntu/keyd/default.conf](ubuntu/keyd/default.conf)。

- Bash 搭配 ble.sh，提供補全、語法高亮及多終端歷史同步；預設編輯器為 `nvim`。
- 安裝 VS Code、SSH server、C/C++ 開發工具及 X11／Wayland 剪貼簿工具。
- Ubuntu 22.04 安裝 ROS 2 Humble 與開發工具；shell 偵測到 `/opt/ros/humble/setup.bash` 時自動載入。24.04 略過 Humble 安裝。
- Neovim 使用官方 tarball，位於 `/opt/neovim/<版本>/`，由 `/usr/local/bin/nvim` 連結；保留舊版本供回復。

| 快捷鍵 | 功能 |
| --- | --- |
| 按住 `Tab` ＋ `h/j/k/l` | keyd 將本機鍵盤映射為左／下／上／右 |
| 單按 `Tab` | 保留原本 Tab 功能 |

keyd 作用於 Ubuntu 本機鍵盤；SSH 的鍵盤操作由連入端終端處理。

### 共用終端設定（Mac／Ubuntu 完整安裝）

| 指令 | 功能 |
| --- | --- |
| `ls`、`l` | eza 列出檔案，目錄優先 |
| `ll`／`la`／`lt` | 詳細列表／包含隱藏檔／兩層目錄樹 |
| `j 關鍵字`／`ji 關鍵字` | zoxide 跳到常用目錄／互動選擇 |
| `bat 檔案` | 語法高亮檢視 |
| `rg 關鍵字`／`fd 檔名` | 搜尋內容／搜尋檔案 |
| `dust -d 2 .` | 查看目前目錄的磁碟占用，顯示至兩層 |
| `btop` | 查看程序、CPU、記憶體與網路 |
| `lazygit` | Git 操作介面，檢查差異、暫存、提交與切換分支 |
| `git diff` | 透過 delta 顯示差異；安裝時只補齊缺少的 Git 顯示設定 |

| 快捷鍵 | 功能 |
| --- | --- |
| `Option+x`（Mac）／`Alt+x`（Ubuntu） | fzf 選取檔案並插入路徑 |
| `Option+c`（Mac）／`Alt+c`（Ubuntu） | fzf 選取並切換目錄 |
| `Ctrl+r` | fzf 搜尋指令歷史 |
| `↑`／`↓` | 依已輸入文字搜尋歷史；Ubuntu 無 ble.sh 時改為前綴搜尋 |
| `?`／`Ctrl+/`（fzf 內） | 切換預覽 |

### Robot

設定入口：[robot/install.sh](robot/install.sh)。

安裝代理切換指令、zellij 與 Codex；重跑只更新 `.bashrc` 中的管理區塊，保留原有 ROS 與機器人設定。安裝程序會開啟 Mac 代理，新終端或重新載入 `.bashrc` 時預設關閉。

| 指令 | 功能 |
| --- | --- |
| `proxy_on` | HTTP／HTTPS 經 Mac 的 `8888` 埠連外 |
| `proxy_off` | 使用機器人原有 Wi-Fi／系統網路；不負責連接 Wi-Fi |
| `zellij attach --create robot` | 建立或接回名為 `robot` 的工作階段 |
| `codex` | 啟動 Codex CLI |

首次啟動 zellij 需下載 autolock 外掛；需要代理時先執行 `proxy_on`。Mac 端可用 `brew services restart tinyproxy` 重啟代理。

### zellij

設定檔：[zellij/config.kdl](zellij/config.kdl)。Mac、Ubuntu、Robot 共用 tokyo-night 主題、簡化介面與 OSC 52 複製；autolock 在 Neovim、fzf、lazygit 等程式前景執行時讓快捷鍵直接傳入。

以下 `→` 表示先按組合鍵，再按下一個鍵；以一般模式為起點。

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl+p → n` | 新增窗格 |
| `Ctrl+p → h/j/k/l` | 切換窗格；`Esc` 返回一般模式 |
| `Ctrl+p → w`／`r` | 切換窗格全螢幕／重新命名 |
| `Ctrl+t → n` | 新增分頁 |
| `Ctrl+t → 1…9` | 切換指定分頁 |
| `Ctrl+n → h/j/k/l` | 調整窗格大小；`Esc` 返回一般模式 |
| `Ctrl+s → s` | 搜尋終端捲動紀錄 |
| `Ctrl+o → d` | 離開並保留工作階段，之後可 attach 接回 |
| `Ctrl+o → w` | 開啟工作階段管理器 |
| `Ctrl+g` | 切換鎖定模式；鎖定時其他快捷鍵傳給前景程式 |
| `Ctrl+q` | 結束工作階段 |

autolock 鎖定時，可先按 `Ctrl+g` 回到一般模式。SSH 斷線後，以原本名稱執行 `zellij attach --create robot` 即可接回仍在運行的工作階段。

### LazyVim

設定目錄：[ubuntu/nvim/config](ubuntu/nvim/config)。Ubuntu 完整安裝會套用；Mac 安裝只準備 Neovim 與 providers，Robot 安裝目前未包含 LazyVim。

提供檔案搜尋、語法解析、補全、格式化與 Git 整合。首次開啟 `nvim` 保持網路連線，待外掛安裝後執行 `:Lazy restore`，再以 `:checkhealth` 檢查依賴。

以下在一般模式使用，`Space` 為前導鍵，依序按下：

| 快捷鍵 | 功能 |
| --- | --- |
| `Space Space` | 搜尋專案檔案 |
| `Space /` | 搜尋專案文字 |
| `Space g g` | 開啟 lazygit，需已安裝執行檔 |
| `Space c f` | 格式化，需有對應 formatter |
| `Space b d` | 關閉目前 buffer |
| `Ctrl+h/j/k/l` | 切換編輯器分割視窗 |
| `Ctrl+s` | 儲存檔案 |
| `Space l` | 開啟外掛管理器 |

對應鎖定版本的上游定義：[一般快捷鍵](https://github.com/LazyVim/LazyVim/blob/c10948c50b18fae7f256433afdef09e432410480/lua/lazyvim/config/keymaps.lua)、[搜尋快捷鍵](https://github.com/LazyVim/LazyVim/blob/c10948c50b18fae7f256433afdef09e432410480/lua/lazyvim/plugins/extras/editor/snacks_picker.lua)。

### Python／Node

Mac／Ubuntu 完整安裝由 uv 管理 Python 3.12 與 pynvim，保留原本的 `python3`。Neovim Python provider 為 `~/.local/bin/pynvim-python`；Node 使用 nvm，安裝時沿用可用的預設版本，否則安裝 LTS。

NumPy／OpenCV 等按專案安裝：

```bash
uv init --python 3.12 my-project
cd my-project
uv add numpy opencv-python
uv run python -c 'import numpy, cv2; print(cv2.__version__)'
```

無桌面影像處理可將 OpenCV 換成 `opencv-python-headless`，同一環境擇一安裝。ROS／系統依賴繼續交給 apt；Ubuntu 22.04 的 Humble 工作區沿用相容的系統 Python。

檢查環境：`uv python list --only-installed`、`uv tool list`、`nvim '+checkhealth vim.provider'`。共用腳本會遷移 pipx 的 pynvim，保留其他 pipx 工具。

### Tailscale

| 平台 | 安裝行為 |
| --- | --- |
| Mac | 完整安裝會啟用；優先使用 App，已有 Homebrew CLI 版時沿用；首次需允許網路擴充功能／VPN 並登入 |
| Ubuntu | 安裝結束時詢問，預設略過；同意後另詢問是否設為 exit node，非互動執行則略過 |
| Robot | Robot 腳本不安裝 Tailscale |

使用 `tailscale status` 檢查。Mac App 尚未提供 CLI 指令時，可執行 `TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale status`；App 安裝於家目錄時改用 `~/Applications`。

Ubuntu 設為 exit node 後，若需手動核准，到 [管理後台](https://login.tailscale.com/admin/machines) 的裝置路由設定啟用。Mac 使用 exit node 且需要存取網線上的機器人時，開啟 **Allow Local Network Access**。[官方說明](https://tailscale.com/docs/features/exit-nodes#local-network-access)

## 設定維護

| 路徑 | 用途 |
| --- | --- |
| `mac/`、`ubuntu/`、`robot/` | 各平台安裝入口與設定 |
| `zellij/` | 共用 zellij 安裝器與快捷鍵 |
| `ubuntu/nvim/config/` | 個人 LazyVim 設定與外掛版本鎖定檔 |
| `scripts/install-common.sh` | Mac／Ubuntu 共用的 uv、Python 3.12、pynvim、Node provider 安裝及驗證流程 |
| `scripts/clean-backups.sh` | 預覽或清理安裝腳本產生的設定備份 |

`scripts/` 集中放置跨平台共用流程與維護工具，避免各平台重複維護相同邏輯。

### 同步 Mac 的 LazyVim 設定

在 Mac 專案根目錄回存設定；`--delete` 會刪除目的端多出的 Lua 檔案：

```bash
rsync -av --delete "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lua/" ubuntu/nvim/config/lua/
cp "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json" \
   "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazyvim.json" ubuntu/nvim/config/
git diff -- ubuntu/nvim/
```

檢查後自行提交、推送；Ubuntu 取得更新後執行 `bash ubuntu/nvim/install.sh`。若更改 `init.lua`、`.neoconf.json` 或 `stylua.toml`，也需回存；保留專案 `init.lua` 依家目錄尋找 Python provider 的寫法。

### 清理備份

在專案根目錄執行：

```bash
bash scripts/clean-backups.sh --dry-run  # 預覽符合格式的備份
bash scripts/clean-backups.sh           # 刪除預覽範圍內的備份
```

涵蓋 shell、keyd、tinyproxy、LazyVim 與舊式 zellij 設定備份。新版 zellij 的 `backup.<時間戳>.<隨機字元>/` 目錄及 `/opt/neovim/` 舊版本目前不在清理範圍內。

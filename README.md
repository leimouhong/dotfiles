# dotfiles

macOS、Ubuntu 與機器人的終端設定。線上指令使用 GitHub `main`。

## 安裝

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/install.sh)
source ~/.zshrc
```

安裝時會詢問 Mac／機器人 IP、啟動 tinyproxy，最後啟用 Tailscale 並登入。既有 `.zshrc` 會先備份。

### Ubuntu

適用 Ubuntu 22.04／24.04，amd64／arm64。套用前會備份原有設定。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/install.sh)
source ~/.bashrc
```

### Robot

先完成 Mac 安裝並接上網線：Mac 有線 IP 預設 `192.168.10.10/24`、路由器留空；Robot IP 為 `192.168.10.102`。Mac 保持可上網，並確認 `brew services info tinyproxy` 顯示服務運行。

在機器人執行，代理 IP 請依實際設定修改：

```bash
bash <(curl -fsSL --proxy http://192.168.10.10:8888 --noproxy "" \
  https://raw.githubusercontent.com/leimouhong/dotfiles/main/robot/install.sh)
source ~/.bashrc
```

只設定代理：在安裝指令最後加 `--proxy-only`。安裝過程使用 Mac 代理，新終端預設關閉代理。

載入 `.bashrc` 後，執行 `codex` 會自動在子程序啟用 Mac 代理，並以 `--no-daemon` 獨立啟動；所有參數原樣傳遞，目前終端的代理狀態不受影響。

完整安裝也會將 Codex 設定寫入 `~/.codex/config.toml`（有設定 `CODEX_HOME` 時使用該目錄），Codex 已安裝時仍會套用。既有設定若不同，會先備份至同目錄的 `backup.*` 資料夾，再以安裝範本整份替換。

Codex 預設不詢問命令批准、允許完整檔案與網路存取、使用 `xhigh` 推理及即時網頁搜尋，文字日誌固定寫入 `/home/booster/.codex/log`；終端保留捲動歷史並關閉動畫。`xhigh` 需要目前使用的模型支援。

### 單獨安裝

zellij（Mac／Ubuntu）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/zellij/install.sh)
```

LazyVim 設定（Ubuntu，需先備妥 Neovim、Git 與依賴，並關閉 Neovim）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/nvim/install.sh)
```

本機專案可直接執行 `bash mac/install.sh`、`bash ubuntu/install.sh` 或 `bash robot/install.sh`。Mac／Ubuntu 共用的 Python 與 Neovim 依賴集中在 `scripts/install-common.sh`，完整安裝會自動呼叫。

### 清理備份

先預覽：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/scripts/clean-backups.sh) --dry-run
```

確認後刪除：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/scripts/clean-backups.sh)
```

本機也可執行 `bash scripts/clean-backups.sh --dry-run`，移除 `--dry-run` 即刪除。Codex 會清理 `~/.codex`（有設定 `CODEX_HOME` 時使用該目錄）下，名稱符合 `backup.<時間戳>.<六位隨機字元>` 且含 `config.toml` 的備份目錄；跳過以符號連結指向的備份目錄。

新版 zellij 的 `backup.*` 目錄與 `/opt/neovim/` 舊版本目前不在清理範圍。

## 功能與快捷鍵

### 各平台

| 設定 | 功能 |
| --- | --- |
| [Mac](mac/.zshrc) | zsh 補全、建議與高亮、Starship、fastfetch、Homebrew CLI、Neovim、zellij、uv、tinyproxy、Tailscale |
| [Ubuntu](ubuntu/.bashrc) | Bash／ble.sh、LazyVim、zellij、uv、VS Code、SSH、C/C++ 工具；22.04 加裝 ROS 2 Humble |
| [Robot](robot/install.sh) | Mac 代理、zellij、Codex；保留原有 `.bashrc`、ROS 與廠商設定 |

Mac／Ubuntu 的 Python 3.12 與 pynvim 使用 uv，Node 使用 nvm；系統 Python 與 ROS 依賴繼續由系統管理。NumPy／OpenCV 按專案安裝：

```bash
uv init --python 3.12 my-project
cd my-project
uv add numpy opencv-python
uv run python
```

### Mac／Ubuntu 終端

| 指令／快捷鍵 | 功能 |
| --- | --- |
| `ls`、`l`／`ll`／`la`／`lt` | eza 列表／詳細／含隱藏檔／兩層目錄樹 |
| `j 關鍵字`／`ji 關鍵字` | 跳到常用目錄／互動選擇 |
| `bat 檔案`／`rg 關鍵字`／`fd 檔名` | 高亮閱讀／搜尋內容／搜尋檔案 |
| `dust -d 2 .`／`btop` | 磁碟占用／資源監控 |
| `lazygit`／`git diff` | Git 操作介面／delta 差異顯示 |
| `Option+x`／`Alt+x` | fzf 搜尋檔案並插入路徑 |
| `Option+c`／`Alt+c` | fzf 搜尋並切換目錄 |
| `Ctrl+r`／`↑`／`↓` | 搜尋指令歷史 |
| 按住 `Tab` ＋ `h/j/k/l` | Ubuntu 本機 keyd 方向鍵；單按仍是 Tab |

Mac 的 Option 需設為 Alt／Meta，也可先按 `Esc` 再按 `x`／`c`。

### zellij

[共用設定](zellij/config.kdl)提供分割窗格、分頁、tokyo-night 主題與 autolock。執行 `zellij attach --create robot` 建立或接回工作階段；首次啟動需連網下載外掛。

`→` 表示依序按鍵；以下從一般模式操作：

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl+p → n`／`h/j/k/l`／`w` | 新增窗格／切換窗格／全螢幕 |
| `Ctrl+t → n`／`1…9` | 新增分頁／切換分頁 |
| `Ctrl+o → d` | 離開並保留工作階段 |
| `Ctrl+o → w` | 工作階段管理器 |
| `Ctrl+g` | 鎖定／解鎖快捷鍵；autolock 鎖定時也可手動解鎖 |
| `Esc` | 從窗格、分頁等模式回到一般模式 |

### LazyVim

Ubuntu 完整安裝會套用[個人設定](ubuntu/nvim/config)；Mac 沿用原有 Neovim 設定，Robot 不會安裝 LazyVim。首次啟動後執行 `:Lazy restore`、`:checkhealth`。

| 快捷鍵（一般模式） | 功能 |
| --- | --- |
| `Space Space`／`Space /` | 搜尋檔案／專案文字 |
| `Space g g`／`Space c f` | lazygit／格式化，需對應工具 |
| `Ctrl+s`／`Space b d` | 儲存／關閉 buffer |
| `Ctrl+h/j/k/l` | 切換分割視窗 |

### 代理與 Tailscale

- **Robot**：`proxy_on` 經 Mac 代理；`proxy_off` 使用原有網路，不會自動連接 Wi-Fi。
- **Mac**：`brew services restart tinyproxy` 重啟代理。Tailscale 隨完整安裝啟用。
- **Ubuntu**：安裝最後詢問是否啟用 Tailscale／exit node，預設略過。
- **連線檢查**：`tailscale status`，或從 Mac 的 Tailscale App 查看。使用 exit node 連接本地機器人時，開啟 **Allow Local Network Access**。

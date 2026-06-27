# dotfiles

個人 shell 設定檔，支援 macOS（zsh）與 Ubuntu（bash）。重點放在快速啟動、常用 CLI 工具整合，以及在缺少部分工具時仍能安全 fallback。

## 快速開始

macOS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/mac/install.sh)
```

Ubuntu 22.04 / 24.04（amd64 / arm64 自動偵測）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/leimouhong/dotfiles/main/ubuntu/install.sh)
```

安裝腳本會備份既有 shell / Neovim 設定後再套用新檔案。

## 內容

```text
dotfiles/
├── mac/
│   ├── .zshrc      # macOS zsh 設定
│   └── install.sh  # macOS 一鍵安裝腳本
└── ubuntu/
    ├── .bashrc            # Ubuntu bash 設定
    ├── install.sh         # Ubuntu 一鍵安裝腳本
    └── keyd/default.conf  # Ubuntu keyd 鍵盤映射
```

## 共用功能

- [eza](https://github.com/eza-community/eza)：現代化 `ls` 替代品。
- [fzf](https://github.com/junegunn/fzf)：模糊搜尋檔案、目錄與歷史。
- [fd](https://github.com/sharkdp/fd)：作為 fzf 的快速搜尋後端。
- [zoxide](https://github.com/ajeetdsouza/zoxide)：智慧目錄跳轉，提供 `j` alias。
- [LazyVim](https://www.lazyvim.org)：Neovim starter 設定。
- [nvm](https://github.com/nvm-sh/nvm)：懶載入 Node.js 版本管理。
- 大量 history：保留 100,000 筆，減少重複與空白紀錄。

## 快捷鍵

| 快捷鍵 | macOS zsh | Ubuntu bash | 功能 |
| --- | --- | --- | --- |
| `Opt-X` / `Alt-X` | 有 | 有 | 用 fzf 搜尋檔案，選中後插入命令列 |
| `Opt-C` / `Alt-C` | 有 | 有 | 用 fzf 搜尋目錄，選中後直接跳轉 |
| `Ctrl-R` | shell 預設 | 有 | Ubuntu 用 fzf 搜尋 history；多行命令顯示為單行，選中後保留原始多行內容 |
| `Ctrl-T` | 取消綁定 | 取消綁定 | 避免與自訂 fzf 檔案搜尋鍵衝突 |
| `↑` / `↓` | 有 | 有 | 依目前輸入做 history substring 搜尋 |
| `Opt-←` / `Opt-→` | 有 | shell 預設 | macOS 以單字為單位左右移動游標 |
| `Tab-h/j/k/l` | 無 | 有 | Ubuntu 透過 keyd 將 `Tab` 作為導航層，`h/j/k/l` 對應左/下/上/右 |

fzf 搜尋會使用 `fd` 作為後端；預覽視窗會用 `eza` 顯示目錄內容，檔案則顯示前 50 行。Ubuntu 的 `Ctrl-R` history 搜尋預設使用 fzf history scoring，進入後可再按 `Ctrl-R` 切換排序模式。
Ubuntu 的 ble.sh 會保留語法高亮、一般自動補全、歷史自動補全、Tab 候選選單與選單內過濾；`Ctrl-R` 提供較適合 multiline history 的 fzf 搜尋視圖。

多行 history 的處理策略是保留為單筆紀錄，不拆成多個單行命令。`Ctrl-R` 搜尋時會把多行顯示壓成單行，選中後仍插入原始多行內容；`↑` / `↓` 則依目前輸入做 substring 搜尋。若要檢查某筆多行紀錄，可用 `fc -ln <編號> <編號> | sed -n l`；若要刪除不想保留的紀錄，可用 `history -d <編號>` 後接 `history -w`。

Ubuntu 會從源碼安裝 [keyd](https://github.com/rvaiya/keyd) 的最新穩定 tag，套用 `ubuntu/keyd/default.conf` 到 `/etc/keyd/default.conf`，通過 `keyd check` 後啟用 systemd 服務。單按 `Tab` 仍是正常 Tab；按住 `Tab` 再按 `h/j/k/l` 則輸出方向鍵。

## Ubuntu 開發環境

Ubuntu 安裝腳本會額外安裝一組常用開發工具：

- CLI / 系統工具：`vim`、`nano`、`htop`、`net-tools`、`openssh-server`、`zip`、`unzip`
- 編譯與除錯：`build-essential`、`cmake`、`gdb`、`pkg-config`
- Python / OpenCV：`python3`、`pip`、`venv`、`python3-dev`、`python3-opencv`、`libopencv-dev`
- Python AI 基礎套件：`numpy`、`scipy`、`pandas`、`matplotlib`、`scikit-learn`
- VS Code：透過 Microsoft apt repository 安裝 `code`
- ROS 2 Humble：只在 Ubuntu 22.04 `jammy` 透過 `ros2-apt-source` 安裝 `ros-humble-desktop`、`ros-dev-tools` 與 colcon 工具；Ubuntu 24.04 會略過 Humble

安裝 ROS 2 Humble 後，Ubuntu `.bashrc` 會在 `/opt/ros/humble/setup.bash` 存在時自動 source。

## 平台差異

| 功能 | macOS | Ubuntu |
| --- | --- | --- |
| Shell | zsh | bash |
| 外掛 / 補全 | zinit、fzf-tab | ble.sh、fzf 原生整合 |
| 語法高亮 | zsh-syntax-highlighting | ble.sh |
| 自動建議 | zsh-autosuggestions | ble.sh |
| Prompt | starship | 系統預設 |
| Conda 懶載入 | 有 | 無 |
| fastfetch | 有 | 無 |
| 系統鍵盤映射 | 無 | keyd |
| ROS 2 | 無 | Humble（Ubuntu 22.04） |
| VS Code | 無 | 有 |

## 穩定性與啟動優化

- macOS 會優先保留 `/opt/homebrew/bin`，避免 Apple Silicon 上被 `/usr/local/bin` 的舊 binary 蓋過。
- zoxide / starship init 會快取到 `~/.cache`，並使用 temp file 後再原子替換，避免留下半成品 cache。
- `TERM=dumb` 時 macOS 會跳過 starship，避免非標準終端輸出錯誤。
- Ubuntu 的 PATH 會去重，反覆 `source ~/.bashrc` 不會累加重複路徑。
- 缺少 ble.sh、Kaku、bun、pipx 等可選工具時，rc 會安靜略過。
- Ubuntu keyd 設定會先備份既有 `/etc/keyd/default.conf`，再套用此 repo 的版本。

## 手動套用

只想套用 rc，不跑完整安裝腳本時：

```bash
# macOS
cp mac/.zshrc ~/.zshrc
source ~/.zshrc

# Ubuntu
cp ubuntu/.bashrc ~/.bashrc
source ~/.bashrc
```

建議先自行備份既有設定；完整安裝腳本會自動備份。

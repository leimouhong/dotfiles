# 設定範本：install.sh 會代入使用者輸入，再安裝至 ~/.config/robot/proxy.sh。
# 安裝後由 ~/.bashrc 載入；非互動式腳本請直接 source 安裝後的檔案。
export http_proxy="http://@listen_address@:8888"
export https_proxy="$http_proxy"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$http_proxy"

# 保留既有例外並加入本機及機器人網路，重複 source 不會重複追加。
no_proxy="${no_proxy:-${NO_PROXY:-}}"
for robot_direct_host in localhost 127.0.0.1 ::1 @listen_address@ @client_address@; do
  case ",$no_proxy," in
    *",$robot_direct_host,"*) ;;
    *) no_proxy="${no_proxy:+$no_proxy,}$robot_direct_host" ;;
  esac
done
export no_proxy
export NO_PROXY="$no_proxy"
unset robot_direct_host

# Codex 官方獨立安裝程式的預設執行檔目錄。
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
